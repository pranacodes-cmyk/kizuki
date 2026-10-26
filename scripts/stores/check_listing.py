#!/usr/bin/env python3
"""Validate store/listing.json against App Store / Google Play limits and our own listing rules
before anything is pushed. Usage: python3 scripts/stores/check_listing.py  (exit 1 on problems).

Rules
- Apple: name/subtitle <= 30, keywords <= 100, promotional text <= 170, description/what's new <= 4000.
- Apple keyword field: comma separated without spaces, no duplicates, no word already in the same
  locale's name or subtitle (Apple combines them anyway), no competitor trademarks, no "app"/"free".
- Google Play: title <= 30, short description <= 80, full description <= 4000; title and short
  description avoid Play's banned promo words ("free", "best", "#1", "top", "new", ...) and emoji.
- Truth guard: Kizuki has no free tier, so "free" may only appear as "free trial".
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRADEMARKS = {"duolingo", "kiku", "anki", "migaku", "busuu", "lingodeer", "renshuu", "wanikani", "bunpro", "todaii",
              "memrise", "babbel", "crunchyroll", "netflix", "youtube", "lingopie", "mochi", "heyjapan"}
PLAY_BANNED = {"free", "best", "#1", "top", "new", "sale", "discount", "download", "install", "cheap", "bonus"}
EMOJI = re.compile("[\U0001F300-\U0001FAFF\u2600-\u27BF]")


URL = re.compile(r"https?://\S+")


def words(text):
    return {w for w in re.split(r"[^a-z0-9]+", text.lower()) if w}


def brands(text):
    """Other brands named in visible text (URLs excluded; naming YouTube's player is required)."""
    return sorted((words(URL.sub(" ", text)) & TRADEMARKS) - {"youtube"})


def free_claims(text):
    """Every 'free' that is not part of 'free trial'."""
    return [m.start() for m in re.finditer(r"\bfree\b(?!\s+trial)", text, re.I)]


def _limit(problems, label, value, limit):
    if value is None:
        problems.append(f"{label}: missing")
    elif len(value) > limit:
        problems.append(f"{label}: {len(value)} chars (limit {limit})")


def apple_sets(a):
    """The base en-US set plus extra locales; missing extra fields inherit the base text."""
    base = {k: a.get(k) for k in ("locale", "name", "subtitle", "keywords", "promotionalText", "description", "whatsNew")}
    yield base
    for extra in a.get("extraLocales", []):
        yield {**base, **extra}


def check(listing):
    problems = []
    a = listing["apple"]
    for s in apple_sets(a):
        loc = s["locale"]
        _limit(problems, f"apple[{loc}].name", s["name"], 30)
        _limit(problems, f"apple[{loc}].subtitle", s["subtitle"], 30)
        _limit(problems, f"apple[{loc}].keywords", s["keywords"], 100)
        _limit(problems, f"apple[{loc}].promotionalText", s["promotionalText"], 170)
        _limit(problems, f"apple[{loc}].description", s["description"], 4000)
        _limit(problems, f"apple[{loc}].whatsNew", s["whatsNew"], 4000)
        kw = s["keywords"] or ""
        terms = kw.split(",")
        if any(t != t.strip() or not t for t in terms):
            problems.append(f"apple[{loc}].keywords: remove spaces/empty entries around commas")
        dupes = sorted({t for t in terms if terms.count(t) > 1})
        if dupes:
            problems.append(f"apple[{loc}].keywords: duplicates {dupes}")
        shown = words(s["name"] or "") | words(s["subtitle"] or "")
        repeated = sorted(words(kw) & shown)
        if repeated:
            problems.append(f"apple[{loc}].keywords: already in name/subtitle {repeated}")
        bad = sorted(words(kw) & (TRADEMARKS | {"app", "free"}))
        if bad:
            problems.append(f"apple[{loc}].keywords: not allowed {bad}")
        for field in ("name", "subtitle", "promotionalText", "description"):
            if s[field] and brands(s[field]):
                problems.append(f"apple[{loc}].{field}: mentions another brand {brands(s[field])}")
            if s[field] and free_claims(s[field]):
                problems.append(f"apple[{loc}].{field}: 'free' outside 'free trial' (there is no free tier)")

    p = listing["play"]
    _limit(problems, "play.title", p.get("title"), 30)
    _limit(problems, "play.shortDescription", p.get("shortDescription"), 80)
    _limit(problems, "play.fullDescription", p.get("fullDescription"), 4000)
    for field in ("title", "shortDescription"):
        text = p.get(field) or ""
        banned = sorted(w for w in PLAY_BANNED if re.search(rf"(?<![\w#]){re.escape(w)}(?!\w)", text, re.I))
        if banned:
            problems.append(f"play.{field}: Play does not allow promo words {banned}")
        if EMOJI.search(text):
            problems.append(f"play.{field}: no emoji allowed")
    for field in ("title", "shortDescription", "fullDescription"):
        text = p.get(field) or ""
        if brands(text):
            problems.append(f"play.{field}: mentions another brand {brands(text)}")
        if free_claims(text):
            problems.append(f"play.{field}: 'free' outside 'free trial' (there is no free tier)")
    return problems


def warnings(listing):
    """Not blocking, but worth fixing: links that carry a competitor's name."""
    def strings(v):
        if isinstance(v, str):
            yield v
        elif isinstance(v, dict):
            for x in v.values():
                yield from strings(x)
        elif isinstance(v, list):
            for x in v:
                yield from strings(x)
    urls = {u for text in strings(listing) for u in URL.findall(text)}
    return [f"link contains another brand's name: {u}" for u in sorted(urls) if words(u) & (TRADEMARKS - {"youtube"})]


def report(listing):
    a, p = listing["apple"], listing["play"]
    for s in apple_sets(a):
        print(f"apple[{s['locale']}] name {len(s['name'])}/30 · subtitle {len(s['subtitle'])}/30 · keywords {len(s['keywords'])}/100 · "
              f"promo {len(s['promotionalText'])}/170 · description {len(s['description'])}/4000")
    print(f"play title {len(p['title'])}/30 · short {len(p['shortDescription'])}/80 · full {len(p['fullDescription'])}/4000")


def main():
    listing = json.loads((ROOT / "store/listing.json").read_text())
    report(listing)
    problems = check(listing)
    for w in sorted(set(warnings(listing))):
        print("!", w)
    for m in problems:
        print("✗", m)
    if problems:
        raise SystemExit(1)
    print("✓ listing passes all store checks")


if __name__ == "__main__":
    main()
