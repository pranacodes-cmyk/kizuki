#!/usr/bin/env python3
"""Push the store listing (text, category, age rating, screenshots, graphics) to App Store Connect
and Google Play from store/listing.json + store/screenshots + store/play.

Usage: python3 scripts/stores/push_listing.py [apple|play|all] [--text-only]   (default: all)
--text-only updates names, subtitles, keywords and descriptions but keeps the approved screenshots,
icon and feature graphic already in the stores (new Apple locales still get the approved screenshots).
The listing is validated by check_listing.py first; nothing is sent when a check fails.
Idempotent: re-running replaces the text (and, without --text-only, the screenshot sets) with the current files.
Things the APIs cannot set (App Privacy answers, review contact, Play Data safety, content rating
questionnaire) are printed at the end as manual steps.
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

from check_listing import apple_sets, check
from common import PLAY_UPLOAD, asc, asc_app, play, play_token

ROOT = Path(__file__).resolve().parents[2]
LISTING = json.loads((ROOT / "store/listing.json").read_text())
IOS_SHOTS = sorted((ROOT / "store/screenshots/ios").glob("*.png"))
PLAY_SHOTS = sorted((ROOT / "store/screenshots/play").glob("*.png"))
manual = []
TEXT_ONLY = "--text-only" in sys.argv


def step(msg):
    print("•", msg, flush=True)


# ------------------------------------------------------------------ App Store Connect

def apple():
    a = LISTING["apple"]
    app = asc_app()
    aid = app["id"]
    step(f"App Store app {aid} ({app['attributes']['name']})")

    try:
        asc("PATCH", f"/v1/apps/{aid}", {"data": {"type": "apps", "id": aid, "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"}}})
        step("content rights: uses third-party content (YouTube embeds)")
    except RuntimeError as e:
        manual.append(f"App Store → App Information → Content Rights: answer 'Yes, uses third-party content' ({str(e)[:160]})")

    info = next(i for i in asc("GET", f"/v1/apps/{aid}/appInfos")["data"] if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) != "READY_FOR_DISTRIBUTION")
    info_locs = {l["attributes"]["locale"]: l for l in asc("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]}
    for s in apple_sets(a):
        attrs = {"name": s["name"], "subtitle": s["subtitle"], "privacyPolicyUrl": a["privacyPolicyUrl"]}
        if s["locale"] in info_locs:
            lid = info_locs[s["locale"]]["id"]
            asc("PATCH", f"/v1/appInfoLocalizations/{lid}", {"data": {"type": "appInfoLocalizations", "id": lid, "attributes": attrs}})
        else:
            asc("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": {"locale": s["locale"], **attrs},
                                                             "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
        step(f"name/subtitle/privacy URL set for {s['locale']}: {s['name']} — {s['subtitle']}")
    asc("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": a["primaryCategory"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": a["secondaryCategory"]}}}}})
    step(f"categories: {a['primaryCategory']} / {a['secondaryCategory']}")

    _age_rating(info["id"], a["ageRating"])

    versions = asc("GET", f"/v1/apps/{aid}/appStoreVersions", params={"filter[platform]": "IOS", "limit": 10})["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    if not editable:
        raise SystemExit("no editable App Store version found")
    ver = editable[0]
    attrs = {"copyright": a["copyright"]}
    if ver["attributes"]["versionString"] != a["version"]:
        attrs["versionString"] = a["version"]
    asc("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"], "attributes": attrs}})
    step(f"version {a['version']} (copyright {a['copyright']})")
    first_release = len(versions) == 1

    locs = {l["attributes"]["locale"]: l for l in asc("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]}
    for s in apple_sets(a):
        text = {"description": s["description"], "keywords": s["keywords"], "promotionalText": s["promotionalText"],
                "supportUrl": a["supportUrl"], "marketingUrl": a["marketingUrl"]}
        if not first_release:
            text["whatsNew"] = s["whatsNew"]
        loc = locs.get(s["locale"])
        if loc:
            asc("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": text}})
        else:
            loc = asc("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": s["locale"], **text},
                                                                             "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})["data"]
        step(f"{s['locale']}: description, keywords ({len(s['keywords'])}/100), promotional text, support + marketing URLs set")
        if not TEXT_ONLY or not _has_screenshots(loc["id"], "APP_IPHONE_67"):
            _screenshots(loc["id"], "APP_IPHONE_67", IOS_SHOTS)
        else:
            step(f"{s['locale']}: approved screenshots kept")

    try:
        asc("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreReviewDetail")
    except RuntimeError:
        pass
    manual.append("App Store → App Review Information: add your name, phone and email (Apple only uses them to contact you during review); no demo account needed")
    manual.append("App Store → App Privacy: answer the data questions (email for accounts, purchases, device ID for ads measurement, usage data) — Apple has no API for this")
    manual.append(f"App Store → version {a['version']} → Build: pick the build after the iPhone build is uploaded, then Add for Review")


def _age_rating(info_id, wanted):
    try:
        decl = asc("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")["data"]
    except RuntimeError as e:
        manual.append(f"App Store → Age Rating: fill the questionnaire ({str(e)[:120]})")
        return
    attrs = {k: v for k, v in wanted.items() if k in decl["attributes"]}
    skipped = sorted(set(wanted) - set(attrs))
    for _ in range(4):
        try:
            asc("PATCH", f"/v1/ageRatingDeclarations/{decl['id']}", {"data": {"type": "ageRatingDeclarations", "id": decl["id"], "attributes": attrs}})
            step(f"age rating questionnaire answered ({len(attrs)} answers)")
            break
        except RuntimeError as e:
            bad = [k for k in attrs if k in str(e)]
            if not bad:
                manual.append(f"App Store → Age Rating: finish the questionnaire ({str(e)[:200]})")
                return
            for k in bad:
                attrs.pop(k)
                skipped.append(k)
    optional = {"kidsAgeBand", "developerAgeRatingInfoUrl", "gracRatingClassificationNumber", "socialMediaAgeRestricted"}
    left = [k for k, v in decl["attributes"].items() if v is None and k not in attrs and k not in optional]
    if left:
        manual.append("App Store → Age Rating: answer the remaining new questions: " + ", ".join(sorted(left)))


def _has_screenshots(loc_id, display_type):
    sets = asc("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]
    s = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == display_type), None)
    return bool(s and asc("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"])


def _screenshots(loc_id, display_type, files):
    sets = asc("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]
    s = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == display_type), None)
    if not s:
        s = asc("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
                                                           "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]
    for old in asc("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"]:
        asc("DELETE", f"/v1/appScreenshots/{old['id']}")
    for f in files:
        data = f.read_bytes()
        shot = asc("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                                                           "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": s["id"]}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            r = requests.request(op["method"], op["url"], data=chunk, timeout=300, headers={h["name"]: h["value"] for h in op.get("requestHeaders") or []})
            if r.status_code >= 300:
                raise RuntimeError(f"screenshot upload {f.name} -> {r.status_code}: {r.text[:300]}")
        asc("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"], "attributes": {
            "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    step(f"{len(files)} iPhone screenshots uploaded ({display_type})")


# ------------------------------------------------------------------ Google Play

def google():
    p = LISTING["play"]
    edit = play("POST", "/edits", {})["id"]
    details = play("GET", f"/edits/{edit}/details")
    step(f"Play app details: default language {details.get('defaultLanguage')}, contact email {'set' if details.get('contactEmail') else 'missing'}")
    lang = details.get("defaultLanguage") or p["language"]
    email = p.get("contactEmail") or details.get("contactEmail")
    patch = {"contactWebsite": p["contactWebsite"]}
    if email:
        patch["contactEmail"] = email
    try:
        play("PATCH", f"/edits/{edit}/details", patch)
    except RuntimeError as e:
        manual.append(f"Google Play → Store settings → Store listing contact details: add website + email ({str(e)[:160]})")
    if not email:
        raise RuntimeError("Google Play needs a public contact email before it saves the listing: set play.contactEmail in store/listing.json")

    play("PUT", f"/edits/{edit}/listings/{lang}", {"language": lang, "title": p["title"], "shortDescription": p["shortDescription"], "fullDescription": p["fullDescription"]})
    step(f"title, short + full description set ({lang})")

    def upload(kind, path):
        r = requests.post(f"{PLAY_UPLOAD}/edits/{edit}/listings/{lang}/{kind}", params={"uploadType": "media"}, data=path.read_bytes(), timeout=300,
                          headers={"Authorization": f"Bearer {play_token()}", "Content-Type": "image/png"})
        if r.status_code != 200:
            raise RuntimeError(f"Play image {kind}/{path.name} -> {r.status_code}: {r.text[:400]}")

    if TEXT_ONLY:
        step("approved icon, feature graphic and screenshots kept")
    else:
        for kind in ("phoneScreenshots", "icon", "featureGraphic"):
            play("DELETE", f"/edits/{edit}/listings/{lang}/{kind}")
        upload("icon", ROOT / "store/play/icon-512.png")
        upload("featureGraphic", ROOT / "store/play/feature-graphic.png")
        for f in PLAY_SHOTS:
            upload("phoneScreenshots", f)
        step(f"icon, feature graphic and {len(PLAY_SHOTS)} phone screenshots uploaded")

    try:
        play("POST", f"/edits/{edit}:commit")
    except RuntimeError as e:
        if "changesNotSentForReview" not in str(e):
            raise
        play("POST", f"/edits/{edit}:commit", params={"changesNotSentForReview": "true"})
    step("Play listing committed")
    manual.append("Google Play → App content: Privacy policy URL, Ads (No), App access (all features available without login), Content rating questionnaire, Target audience (18+ / 13+), Data safety form")
    manual.append("Google Play → Store settings: app category Education, tags (Language learning)")


def main():
    flags = [x for x in sys.argv[1:] if x.startswith("-")]
    args = [x for x in sys.argv[1:] if not x.startswith("-")]
    # Anything unexpected (including --help) prints usage and sends nothing: this script changes live store listings.
    if any(f != "--text-only" for f in flags) or len(args) > 1 or (args and args[0] not in ("apple", "play", "all")):
        print(__doc__)
        raise SystemExit(0 if {"-h", "--help"} & set(flags) else 2)
    which = args[0] if args else "all"
    problems = check(LISTING)
    if problems:
        raise SystemExit("listing check failed, nothing pushed:\n- " + "\n- ".join(problems))
    failed = []
    for name, fn in (("apple", apple), ("play", google)):
        if which not in ("all", name):
            continue
        print(f"\n=== {name} ===")
        try:
            fn()
        except Exception as e:  # report and continue with the other store
            failed.append(name)
            print(f"FAILED {name}: {e}")
    if manual:
        print("\n=== still to do by hand ===")
        for m in manual:
            print("-", m)
    if failed:
        raise SystemExit(f"failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
