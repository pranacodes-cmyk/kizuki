#!/usr/bin/env python3
"""Durable copy of the content translations (the work cache lives in /tmp and can vanish).

`store(lang)` writes everything that is translated and still matches the current English
library into scripts/i18n/content/<lang>/:
  clips.jsonl.gz    one line per clip: {"id", "src", "res", "reviewed"}
  dict.jsonl.gz     one line per dictionary entry: {"key", "val"} (val.reviewed after the second check)
  grammar.jsonl.gz  one line per grammar description: {"key", "val", "reviewed"?}
Files are sorted and gzip-written with a fixed timestamp, so an unchanged set gives a
byte-identical file. `restore(lang)` rebuilds the work cache from it, so runs resume without
paying for the same translation twice.

  python3 scripts/i18n/store_content.py store   --lang vi,id
  python3 scripts/i18n/store_content.py restore --lang vi
"""
import argparse
import glob
import gzip
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import translate_content as tc  # noqa: E402

STORE = os.path.join(HERE, "content")


def _write_gz(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0, compresslevel=9) as gz:
        for r in rows:
            gz.write((json.dumps(r, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8"))
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(buf.getvalue())
    os.replace(tmp, path)


def _read_gz(path):
    if not os.path.exists(path):
        return []
    with gzip.open(path, "rt", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def store(lang):
    _, clips = tc.load_library()
    rows, stale = [], 0
    for c in sorted(clips, key=lambda c: c["id"]):
        f = tc.clip_file(lang, c["id"])
        if not os.path.exists(f):
            continue
        rec = json.load(open(f, encoding="utf-8"))
        notes = tc.load_notes(c["id"])
        if rec.get("src") != tc.h(tc.clip_source(c, notes)):
            stale += 1
            continue
        rows.append({"id": c["id"], "src": rec["src"], "res": rec["res"], "reviewed": rec.get("review") is not None})
    # Keep stored clips the cache no longer has (e.g. after a sandbox reset), if still current.
    have = {r["id"] for r in rows}
    current = {c["id"]: c for c in clips}
    for old in _read_gz(os.path.join(STORE, lang, "clips.jsonl.gz")):
        c = current.get(old["id"])
        if old["id"] in have or not c:
            continue
        if old["src"] == tc.h(tc.clip_source(c, tc.load_notes(c["id"]))):
            rows.append(old)
    rows.sort(key=lambda r: r["id"])
    _write_gz(os.path.join(STORE, lang, "clips.jsonl.gz"), rows)

    out = {}
    for kind in ("dict", "grammar"):
        _, cache = tc.jsonl_cache(lang, kind)
        merged = {r["key"]: r["val"] for r in _read_gz(os.path.join(STORE, lang, f"{kind}.jsonl.gz"))}
        merged.update(cache)
        if kind == "dict":
            d = tc.dict_entries()
            merged = {k: v for k, v in merged.items() if k in d and v.get("src") == tc.h([d[k]["m"], d[k]["ex"]])}
        if kind == "grammar":
            # The second check's mark lives beside the text (dictionary rows carry it in val).
            rev = {r["key"] for r in _read_gz(os.path.join(STORE, lang, "grammar.jsonl.gz")) if r.get("reviewed")} | tc.grammar_reviewed(lang)
            rows_out = [{"key": k, "val": merged[k], **({"reviewed": True} if k in rev else {})} for k in sorted(merged)]
        else:
            rows_out = [{"key": k, "val": merged[k]} for k in sorted(merged)]
        _write_gz(os.path.join(STORE, lang, f"{kind}.jsonl.gz"), rows_out)
        out[kind] = len(merged)
    reviewed = sum(1 for r in rows if r["reviewed"])
    print(f"[{lang}] stored clips {len(rows)} (reviewed {reviewed}, {stale} stale skipped) | dict {out['dict']} | grammar {out['grammar']}")


def restore(lang):
    n = 0
    for r in _read_gz(os.path.join(STORE, lang, "clips.jsonl.gz")):
        f = tc.clip_file(lang, r["id"])
        if os.path.exists(f):
            continue
        review = {"applied": [], "rejected": [], "restored": True} if r["reviewed"] else None
        tc.write_json(f, {"src": r["src"], "res": r["res"], "review": review})
        n += 1
    for kind in ("dict", "grammar"):
        f, cache = tc.jsonl_cache(lang, kind)
        rows = [r for r in _read_gz(os.path.join(STORE, lang, f"{kind}.jsonl.gz")) if r["key"] not in cache]
        if rows:
            tc.append_jsonl(f, rows)
    print(f"[{lang}] restored {n} clips into {tc.WORK}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["store", "restore"])
    ap.add_argument("--lang", default=",".join(tc.LANGS))
    a = ap.parse_args()
    for lang in a.lang.split(","):
        (store if a.cmd == "store" else restore)(lang)


if __name__ == "__main__":
    main()
