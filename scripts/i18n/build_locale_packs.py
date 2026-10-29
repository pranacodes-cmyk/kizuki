#!/usr/bin/env python3
"""Builds the language packs from the durable translations (scripts/i18n/content/<lang>/).

Per language it writes:
  • the downloadable pack into /tmp/locale-packs/<lang>/ — lines.json, dict.json, grammar.json and
    notes-00…31.json (clips spread by localeNoteShard) plus pack.json (file list with sha-256 and
    size of the plain JSON). Publish it with `bun scripts/i18n/publish_locale_packs.ts`.
  • the bundled starter overlay public/data/locale/<lang>.json (+ mobile/assets/data/locale/):
    the curated first clips, their explanations, every dictionary entry their words use and their
    grammar lines — so a new learner's first clips are in their language with no download.

Only translations that passed the automatic checks AND the independent review are shipped
(--include-unreviewed is for local testing only), and only for the exact clip they were made for
(fingerprint = clipLocaleSig in logic.ts / logic.dart).

  python3 scripts/i18n/build_locale_packs.py --lang vi,id,th,ko,pt
"""
import argparse
import gzip
import hashlib
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import translate_content as tc  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
STORE = os.path.join(HERE, "content")
OUT = os.environ.get("KIZUKI_LOCALE_OUT", "/tmp/locale-packs")
BUNDLED = [os.path.join(ROOT, "public", "data", "locale"), os.path.join(ROOT, "mobile", "assets", "data", "locale")]
NOTE_SHARDS = 32  # LOCALE_NOTE_SHARDS


def fnv1a(s):
    h = 0x811C9DC5
    b = s.encode("utf-16-le")
    for i in range(0, len(b), 2):
        h ^= b[i] | (b[i + 1] << 8)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def clip_sig(c):
    return format(fnv1a("\n".join(f"{l['ja']}|{' '.join(w['s'] for w in l['words'])}" for l in c["lines"])), "08x")


def read_gz(path):
    if not os.path.exists(path):
        return []
    with gzip.open(path, "rt", encoding="utf-8") as f:
        return [json.loads(x) for x in f if x.strip()]


def dumps(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def build(lang, include_unreviewed=False, write_bundle=True):
    index, clips = tc.load_library()
    by_id = {c["id"]: c for c in clips}
    stored = {r["id"]: r for r in read_gz(os.path.join(STORE, lang, "clips.jsonl.gz"))}
    dict_rows = {r["key"]: r["val"] for r in read_gz(os.path.join(STORE, lang, "dict.jsonl.gz"))}
    grammar_rows = {r["key"]: r["val"] for r in read_gz(os.path.join(STORE, lang, "grammar.jsonl.gz")) if r.get("reviewed") or include_unreviewed}
    d = tc.dict_entries()

    lines, notes = {}, [dict() for _ in range(NOTE_SHARDS)]
    skipped = {"unreviewed": 0, "stale": 0, "missing": 0}
    for cid, c in sorted(by_id.items()):
        r = stored.get(cid)
        if not r:
            skipped["missing"] += 1
            continue
        n = tc.load_notes(cid)
        if r["src"] != tc.h(tc.clip_source(c, n)):
            skipped["stale"] += 1
            continue
        if not r["reviewed"] and not include_unreviewed:
            skipped["unreviewed"] += 1
            continue
        res, sig = r["res"], clip_sig(c)
        if len(res["l"]) != len(c["lines"]):
            skipped["stale"] += 1
            continue
        lines[cid] = {"s": sig, "t": res["t"], "l": res["l"]}
        w = {k: v for k, v in res["w"].items() if k in n["w"]}
        l = {k: v for k, v in res["n"].items() if k in n["l"]}
        if w or l:
            notes[fnv1a(cid) % NOTE_SHARDS][cid] = {"s": sig, "w": w, "l": l}

    dict_out = {}
    for eid, v in dict_rows.items():
        e = d.get(eid)
        if e and v.get("src") == tc.h([e["m"], e["ex"]]) and len(v["m"]) == len(e["m"]) and len(v["ex"]) == len(e["ex"]):
            if not v.get("reviewed") and not include_unreviewed:
                continue
            dict_out[eid] = {"m": v["m"], "ex": v["ex"]}

    grammar_out = {}
    for c in clips:
        for g in c["grammar"]:
            p, desc = tc.split_grammar(g)
            if not desc:
                continue
            t = grammar_rows.get(tc.h([p, desc]))
            if isinstance(t, str) and t.strip():
                grammar_out[g] = f"{p} — {t.strip()}"

    # Downloadable pack.
    out = os.path.join(OUT, lang)
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    texts = {"lines.json": dumps(lines), "dict.json": dumps(dict_out), "grammar.json": dumps(grammar_out)}
    for i, s in enumerate(notes):
        texts[f"notes-{i:02d}.json"] = dumps(s)
    files = []
    for name, text in sorted(texts.items()):
        raw = text.encode("utf-8")
        open(os.path.join(out, name), "wb").write(raw)
        files.append({"name": name, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)})
    content_version = index.get("version", 1)
    json.dump({"lang": lang, "content_version": content_version, "clips": len(lines), "dict": len(dict_out), "grammar": len(grammar_out), "files": files},
              open(os.path.join(out, "pack.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    raw_total = sum(f["bytes"] for f in files)
    gz_total = sum(len(gzip.compress(open(os.path.join(out, f["name"]), "rb").read(), 9)) for f in files)

    # Bundled starter overlay.
    starter = [cid for cid in index.get("starter", []) if cid in lines]
    words = {w["d"] for cid in starter for l in by_id[cid]["lines"] for w in l["words"] if w.get("d")}
    bundle = {
        "lines": {cid: lines[cid] for cid in starter},
        "notes": {cid: notes[fnv1a(cid) % NOTE_SHARDS][cid] for cid in starter if cid in notes[fnv1a(cid) % NOTE_SHARDS]},
        "dict": {eid: dict_out[eid] for eid in sorted(words) if eid in dict_out},
        "grammar": {g: grammar_out[g] for cid in starter for g in by_id[cid]["grammar"] if g in grammar_out},
    }
    text = dumps(bundle)
    for b in (BUNDLED if write_bundle else []):
        os.makedirs(b, exist_ok=True)
        open(os.path.join(b, f"{lang}.json"), "w", encoding="utf-8").write(text)
    print(f"[{lang}] pack: {len(lines)}/{len(clips)} clips, {len(dict_out)}/{len(d)} words, {len(grammar_out)} grammar lines, "
          f"{raw_total / 1e6:.2f} MB → {gz_total / 1e6:.2f} MB download; skipped {skipped} | "
          f"bundled starter: {len(bundle['lines'])} clips, {len(bundle['dict'])} words, {len(text.encode()) / 1e3:.0f} kB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default=",".join(tc.LANGS))
    ap.add_argument("--include-unreviewed", action="store_true")
    ap.add_argument("--no-bundle", action="store_true", help="only the downloadable pack (tests)")
    a = ap.parse_args()
    if a.include_unreviewed and not a.no_bundle:
        sys.exit("--include-unreviewed is for test packs only: add --no-bundle")
    for lang in a.lang.split(","):
        build(lang, a.include_unreviewed, not a.no_bundle)


if __name__ == "__main__":
    main()
