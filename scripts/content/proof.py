#!/usr/bin/env python3
"""Step 1b of the content pipeline: proofread AI transcripts before they are tokenised.

Video transcription sometimes picks the wrong kanji for a correctly heard word
(e.g. 行けない where いけない "must not" was meant). For every clip in
public/data/content.json without scripts/content/proof/<clipId>.json, the default chat model
reviews each line against its English and the scene, and returns corrected orthography only
(never new content). build.ts applies the corrections on the next run.

Usage: python3 scripts/content/proof.py [--workers 6]
"""
import argparse, concurrent.futures as cf, json, os, time, urllib.error
from explain import stream, MODEL, CONTENT, load_clips  # same gateway client + model

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "proof")

SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["fixes"],
    "properties": {"fixes": {"type": "array", "items": {
        "type": "object", "additionalProperties": False, "required": ["line", "ja", "en", "why"],
        "properties": {
            "line": {"type": "integer"},
            "ja": {"type": "string"},
            "en": {"type": "string"},
            "why": {"type": "string"},
        }}}},
}

INSTRUCTIONS = """You proofread Japanese subtitles produced by speech recognition for a learner app.
Each line has Japanese and an English translation. Only fix clear ORTHOGRAPHY or
recognition mistakes: wrong kanji for the heard word (行けない→いけない when it means "must not"),
kanji that natives write in kana in this context, wrong homophones, broken okurigana, missing
sentence-final punctuation, or an English translation that is wrong. Keep the same spoken
words and meaning — never rewrite style, never add or remove words. Return only lines that need a
fix, with the full corrected Japanese (ja), the corrected or original English (en) and a 3-8 word
reason (why). Return an empty list when everything is fine (that is the usual case)."""


def work(clip):
    out = os.path.join(OUT, f"{clip['id']}.json")
    if os.path.exists(out):
        return clip["id"], "cached"
    prompt = f"Scene: {clip['title']}\n" + "\n".join(
        f"Line {i}: {l['ja']}  (English: {l['en']})" for i, l in enumerate(clip["lines"]))
    body = {
        "model": MODEL, "instructions": INSTRUCTIONS, "input": prompt,
        "reasoning": {"effort": "medium"}, "store": False, "stream": True,
        "text": {"format": {"type": "json_schema", "name": "proof", "strict": True, "schema": SCHEMA}},
    }
    last = None
    for attempt in range(3):
        try:
            data = json.loads(stream(body))
            fixes = [f for f in data["fixes"] if 0 <= f["line"] < len(clip["lines"])
                     and f["ja"].strip() and f["ja"].strip() != clip["lines"][f["line"]]["ja"]]
            json.dump({"fixes": fixes}, open(out, "w", encoding="utf-8"), ensure_ascii=False)
            return clip["id"], f"ok {len(fixes)} fixes"
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code} {e.read()[:300]!r}"
            if e.code not in (429, 500, 502, 503, 504):
                break
        except Exception as e:
            last = repr(e)[:300]
        time.sleep(8 * (attempt + 1))
    return clip["id"], f"FAIL {last}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=6)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    clips = load_clips()
    with cf.ThreadPoolExecutor(a.workers) as ex:
        for cid, status in ex.map(work, clips):
            print(cid, status, flush=True)


if __name__ == "__main__":
    main()
