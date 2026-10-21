#!/usr/bin/env python3
"""Step 2 of the content pipeline: AI "meaning in this sentence" notes for every word.

Reads public/data/content.json (built by build.ts) and, for every clip without a cached
scripts/content/explain/<clipId>.json, asks the Lovable AI Gateway (default chat model,
Responses API, strict JSON schema, streamed) to explain each word in context.
Re-run build.ts afterwards to copy the notes into both clients.

Usage: python3 scripts/content/explain.py [--workers 6] [--limit N]
"""
import argparse, concurrent.futures as cf, hashlib, json, os, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "explain")
CONTENT = os.path.join(ROOT, "..", "..", "public", "data", "content.json")
MODEL = "openai/gpt-6-astra"
URL = "https://ai.gateway.lovable.dev/v1/responses"

SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["words", "lines"],
    "properties": {
        "words": {"type": "array", "items": {
            "type": "object", "additionalProperties": False, "required": ["id", "meaning", "note"],
            "properties": {
                "id": {"type": "string"},
                "meaning": {"type": "string"},
                "note": {"type": "string"},
            }}},
        "lines": {"type": "array", "items": {
            "type": "object", "additionalProperties": False, "required": ["line", "literal", "tip"],
            "properties": {
                "line": {"type": "integer"},
                "literal": {"type": "string"},
                "tip": {"type": "string"},
            }}},
    },
}

INSTRUCTIONS = """You are a friendly, precise Japanese tutor writing pop-up notes for an app where
beginners tap words in real Japanese video subtitles. For EVERY word id given, write:
- meaning: what the word means IN THIS SENTENCE, 1-6 English words (no romaji, no quotes).
- note: one short sentence (max 22 words) on how it is used here: conjugation/form (e.g. "て-form
  of 歩く + てる = is walking"), particle role, nuance, politeness or slang. Plain English, no jargon
  without explaining it. Never repeat the meaning field verbatim.
For every line write:
- literal: a word-by-word literal English rendering (max 20 words).
- tip: one short sentence (max 22 words) with the single most useful thing to notice in the line.
Be accurate. If a word is a name, say so."""


def token_sig(clip):
    """Same fingerprint as tokenSig() in build.ts: notes are only valid for this word split."""
    joined = "\n".join("|".join(w["s"] for w in l["words"]) for l in clip["lines"])
    return hashlib.sha1(joined.encode("utf-8")).hexdigest()[:12]


def clip_prompt(clip):
    rows = []
    for li, line in enumerate(clip["lines"]):
        rows.append(f"Line {li}: {line['ja']}  (English: {line['en']})")
        ids = [f"{li}.{wi}={w['s']}" + (f"[{w['b']}]" if w['b'] and w['b'] != w['s'] else "")
               for wi, w in enumerate(line["words"]) if w["p"] != "punct"]
        rows.append("  words: " + "  ".join(ids))
    return "\n".join(rows)


def stream(body):
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), headers={
        "Authorization": f"Bearer {os.environ['LOVABLE_API_KEY']}",
        "Content-Type": "application/json",
        "X-Lovable-AIG-SDK": "fetch",
        "Accept": "text/event-stream",
    })
    text = []
    with urllib.request.urlopen(req, timeout=600) as r:
        for raw in r:
            line = raw.decode("utf-8").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if not data or data == "[DONE]":
                continue
            ev = json.loads(data)
            t = ev.get("type")
            if t == "response.output_text.delta":
                text.append(ev["delta"])
            elif t in ("response.failed", "error"):
                raise RuntimeError(json.dumps(ev)[:400])
            elif t == "response.incomplete":
                raise RuntimeError("incomplete: " + json.dumps(ev.get("response", {}).get("incomplete_details")))
    return "".join(text)


def work(clip):
    out = os.path.join(OUT, f"{clip['id']}.json")
    sig = token_sig(clip)
    if os.path.exists(out):
        cached = json.load(open(out, encoding="utf-8"))
        if cached.get("sig", sig) == sig:
            return clip["id"], "cached"
    body = {
        "model": MODEL,
        "instructions": INSTRUCTIONS,
        "input": clip_prompt(clip),
        "reasoning": {"effort": "low"},
        "store": False,
        "stream": True,
        "text": {"format": {"type": "json_schema", "name": "notes", "strict": True, "schema": SCHEMA}},
    }
    last = None
    for attempt in range(3):
        try:
            data = json.loads(stream(body))
            words = {w["id"]: {"m": w["meaning"].strip(), "n": w["note"].strip()} for w in data["words"]}
            lines = {str(l["line"]): {"lit": l["literal"].strip(), "tip": l["tip"].strip()} for l in data["lines"]}
            json.dump({"sig": sig, "w": words, "l": lines}, open(out, "w", encoding="utf-8"), ensure_ascii=False)
            want = sum(1 for l in clip["lines"] for w in l["words"] if w["p"] != "punct")
            return clip["id"], f"ok {len(words)}/{want}"
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
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--only")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    clips = json.load(open(CONTENT, encoding="utf-8"))["clips"]
    if a.only:
        clips = [c for c in clips if c["id"] in a.only.split(",")]
    if a.limit:
        clips = clips[: a.limit]
    with cf.ThreadPoolExecutor(a.workers) as ex:
        for cid, status in ex.map(work, clips):
            print(cid, status, flush=True)


if __name__ == "__main__":
    main()
