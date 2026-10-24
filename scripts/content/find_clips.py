#!/usr/bin/env python3
"""Step 1 of the content pipeline.

For every hand-picked YouTube video (scripts/content/picks.txt) ask Gemini to watch the
video through its official YouTube-URL input (no download, no re-hosting) and return
learner-friendly clip windows with verbatim Japanese lines, timings and translations.

Output: scripts/content/raw/<videoId>.json (one file per video, resumable).
Usage: python3 scripts/content/find_clips.py [--only ID,ID] [--workers 8]
"""
import argparse, concurrent.futures as cf, json, os, re, sys, time, urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ROOT, "raw")
MODEL = os.environ.get("CLIP_MODEL", "google/gemini-3.8-flash")
URL = "https://ai.gateway.lovable.dev/v1/chat/completions"
TOPICS = ["travel", "anime", "work", "fun", "friends", "family", "romance", "culture",
          "food", "daily", "animals", "school", "comedy", "sports", "music"]

PROMPT = """You are a senior Japanese subtitler building a listening app for learners.
Watch this whole YouTube video carefully (audio + picture).

Pick up to {n} separate moments (each 7–35 seconds long) where Japanese is SPOKEN clearly
(dialogue, narration, conversation, interview). Good moments are self-contained, fun or
useful, understandable from context, and not drowned by music. Skip singing, credits,
silent parts, and anything sexual, violent/gory or hateful. Prefer moments with 2–8 lines.

For every moment return:
- start/end in seconds from the start of the video (start ~0.3 s before the first word,
  end ~0.5 s after the last word). Use decimals.
- lines: EVERY spoken line inside the window, verbatim, in natural Japanese orthography as a
  native subtitler would write it (kanji + kana, 。、！？ punctuation). Never invent, summarise or
  correct speech; if a word is unclear, choose the most likely word. One line = one short
  utterance (max ~25 characters; split longer sentences). Each line has start/end seconds,
  "en" = natural English translation, "speaker" = short label like "A", "B", "Narrator".
- title: short English title of the moment (max 42 characters, no quotes).
- level: JLPT level that fits the language difficulty: N5, N4, N3, N2 or N1.
- topics: 1–3 from {topics}.
- grammar: 1–3 grammar points that appear, each as "pattern — meaning" e.g. "〜てる — ongoing action".
- quality: 1–5 (5 = crystal clear audio and very good for learners).

Also return "speech": "clear" | "some" | "none" for the video overall.
If there is no clear Japanese speech, return "clips": [].
{length}
Respond with JSON only, no markdown:
{{"speech": "...", "clips": [{{"start": 0.0, "end": 0.0, "title": "...", "level": "N5", "topics": [], "grammar": [], "quality": 5, "lines": [{{"start": 0.0, "end": 0.0, "ja": "...", "en": "...", "speaker": "A"}}]}}]}}
"""


def load_picks():
    picks = []
    for line in open(os.path.join(ROOT, "picks.txt"), encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        vid, *rest = line.split()
        picks.append((vid, rest[0].split(",") if rest else []))
    return picks


LENGTH_HINT = """
IMPORTANT TIMING: this video is exactly {dur:.1f} seconds long ({mm}:{ss:02d}). Every start/end must be
seconds from the start of THIS video and lie between 0 and {dur:.1f}. Read times from the actual
playback position; never estimate or stretch them.
"""


def length_hint(vid):
    """Real length from the official-player library check (verify_library.py), when known."""
    f = os.path.join(ROOT, "playable.json")
    d = (json.load(open(f)).get(vid) or {}).get("duration") if os.path.exists(f) else None
    return LENGTH_HINT.format(dur=d, mm=int(d) // 60, ss=int(d) % 60) if d else ""


def call(vid, n):
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": [
            {"type": "video_url", "video_url": {"url": f"https://www.youtube.com/watch?v={vid}"}},
            {"type": "text", "text": PROMPT.format(n=n, topics=", ".join(TOPICS), length=length_hint(vid))},
        ]}],
    }
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), headers={
        "Authorization": f"Bearer {os.environ['LOVABLE_API_KEY']}",
        "Content-Type": "application/json",
        "X-Lovable-AIG-SDK": "fetch",
    })
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())


def parse(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?", "", text).strip()
    text = re.sub(r"```$", "", text).strip()
    start = text.find("{")
    end = text.rfind("}")
    return json.loads(text[start:end + 1])


FORCE = set()  # --regenerate: re-run these even when cached (stretched timelines)


def work(item):
    vid, topics = item
    out = os.path.join(RAW, f"{vid}.json")
    if os.path.exists(out) and vid not in FORCE:
        return vid, "cached"
    last = None
    for attempt in range(3):
        try:
            res = call(vid, 3)
            msg = res["choices"][0]["message"]["content"]
            data = parse(msg)
            data["videoId"] = vid
            data["pickTopics"] = topics
            data["model"] = MODEL
            if vid in FORCE:
                data["regenerated"] = "real-length hint (verify_library.py)"
            json.dump(data, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            return vid, f"ok {len(data.get('clips', []))} clips"
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code} {e.read()[:300]!r}"
            if e.code not in (429, 500, 502, 503, 504):
                break
        except Exception as e:  # parse / network errors
            last = repr(e)[:300]
        time.sleep(10 * (attempt + 1))
    json.dump({"videoId": vid, "error": last}, open(out + ".err", "w"))
    return vid, f"FAIL {last}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--regenerate", help="JSON list of video ids to re-run with their real length")
    a = ap.parse_args()
    if a.regenerate:
        FORCE.update(json.load(open(a.regenerate)))
    os.makedirs(RAW, exist_ok=True)
    picks = load_picks()
    if a.only:
        want = set(a.only.split(","))
        picks = [p for p in picks if p[0] in want]
    if FORCE:
        picks = [p for p in picks if p[0] in FORCE]
    with cf.ThreadPoolExecutor(a.workers) as ex:
        for vid, status in ex.map(work, picks):
            print(vid, status, flush=True)


if __name__ == "__main__":
    main()
