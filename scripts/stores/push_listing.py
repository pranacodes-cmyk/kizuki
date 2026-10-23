#!/usr/bin/env python3
"""Push the store listing (text, category, age rating, screenshots, graphics) to App Store Connect
and Google Play from store/listing.json + store/screenshots + store/play.

Usage: python3 scripts/stores/push_listing.py [apple|play|all]   (default: all)
Idempotent: re-running replaces the text and the screenshot sets with the current files.
Things the APIs cannot set (App Privacy answers, review contact, Play Data safety, content rating
questionnaire) are printed at the end as manual steps.
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

from common import PLAY_UPLOAD, asc, asc_app, play, play_token

ROOT = Path(__file__).resolve().parents[2]
LISTING = json.loads((ROOT / "store/listing.json").read_text())
IOS_SHOTS = sorted((ROOT / "store/screenshots/ios").glob("*.png"))
PLAY_SHOTS = sorted((ROOT / "store/screenshots/play").glob("*.png"))
manual = []


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
    for loc in asc("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]:
        if loc["attributes"]["locale"] != a["locale"]:
            continue
        asc("PATCH", f"/v1/appInfoLocalizations/{loc['id']}", {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": {
            "name": a["name"], "subtitle": a["subtitle"], "privacyPolicyUrl": a["privacyPolicyUrl"]}}})
        step(f"name/subtitle/privacy URL set for {a['locale']}")
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

    locs = asc("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"] == a["locale"]), None)
    text = {"description": a["description"], "keywords": a["keywords"], "promotionalText": a["promotionalText"],
            "supportUrl": a["supportUrl"], "marketingUrl": a["marketingUrl"]}
    if not first_release:
        text["whatsNew"] = a["whatsNew"]
    if loc:
        asc("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": text}})
    else:
        loc = asc("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": a["locale"], **text},
                                                                         "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})["data"]
    step("description, keywords, promotional text, support + marketing URLs set")

    _screenshots(loc["id"], "APP_IPHONE_67", IOS_SHOTS)

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
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
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
