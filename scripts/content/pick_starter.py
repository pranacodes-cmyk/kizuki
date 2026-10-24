#!/usr/bin/env python3
"""Starter feed curation (run after build.ts; re-runnable, AI ratings are cached).

Everyone's first clips — the phone preview during onboarding and the start of the home feed —
come from one curated, ordered list instead of the personal ranker. This script picks it:

  1. candidates  — rule filter over public/data: beginner-friendly level (N5/N4, a few N3),
                   10–28 s, 3–9 lines, real video (no podcast stills), word notes present,
                   at most 2 windows per video and 4 per channel.
  2. rate        — Gemini watches each candidate's YouTube video through its official URL input
                   (no download) and rates every listed window as a FIRST clip for a new learner:
                   appeal, speech clarity, picture, how easy it is to follow. Cached in
                   scripts/content/starter/<videoId>.json.
  3. select      — best-rated windows with variety rules (1 per video, 2 per channel, topic and
                   level mix), the onboarding showcase clip first, written to
                   scripts/content/starter.json. build.ts copies the ids into content.json.

Usage: python3 scripts/content/pick_starter.py [--workers 24] [--size 48]
"""
import argparse, collections, concurrent.futures as cf, json, os, re, time, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
CACHE = os.path.join(HERE, "starter")
OUT = os.path.join(HERE, "starter.json")
MODEL = os.environ.get("STARTER_MODEL", "google/gemini-3.8-flash")
URL = "https://ai.gateway.lovable.dev/v1/chat/completions"
# The approved first clip for everyone: "Essential Daily Greetings", the opening window of this
# video (its id changes when the video is re-timed, so it is found by video, not by clip id).
SHOWCASE_VIDEO = "0dBf_DAXNuc"
SHOWCASE = None  # set in main() from the current data
LEVEL_WEIGHT = {"N5": 3.0, "N4": 2.2, "N3": 1.2}
FUN_TOPICS = {"fun", "anime", "food", "animals", "travel", "comedy", "culture", "daily", "friends"}

PROMPT = """You are choosing the very FIRST clips a brand-new learner of Japanese sees right after
installing a TikTok-style Japanese listening app. Watch this YouTube video (audio + picture) and
judge ONLY these time windows:
{windows}

For each window score how great it is as one of a newcomer's first ~50 clips:
- appeal 1-10: would a beginner enjoy it and want to keep swiping? (fun, warm, surprising, cute,
  beautiful or culturally interesting beats a dry lecture; real scenes beat static slides)
- clarity 1-5: Japanese speech is clear, natural, not drowned by music or noise
- picture 1-5: the picture is engaging and matches the speech (5 = lively real scene)
- ease 1-5: a beginner can follow it with subtitles (slow/simple = 5)
- english: true if a large part of the window is spoken in English instead of Japanese
- issues: short list of problems (e.g. "mostly silent", "speech overlaps", "sad topic",
  "starts mid-sentence", "loud music", "ad / sponsor", "unsafe content"), empty if none
- why: max 12 words

Respond with JSON only, no markdown:
{{"ratings": [{{"id": "...", "appeal": 0, "clarity": 0, "picture": 0, "ease": 0, "english": false, "issues": [], "why": "..."}}]}}
"""


def load():
    meta = json.load(open(os.path.join(ROOT, "public/data/content.json"), encoding="utf-8"))
    clips = [c for p in meta["parts"] for c in json.load(open(os.path.join(ROOT, "public/data", p), encoding="utf-8"))["clips"]]
    return meta["videos"], clips


def prescore(c):
    dur = c["end"] - c["start"]
    s = LEVEL_WEIGHT.get(c["level"], 0)
    s -= abs(dur - 16) / 8
    s += 0.6 * len(FUN_TOPICS.intersection(c["topics"]))
    s += (c.get("quality", 3) - 4) * 0.5
    return s


def candidates(videos, clips, limit=360):
    ok = []
    for c in clips:
        dur = c["end"] - c["start"]
        if c["level"] not in LEVEL_WEIGHT or c.get("still") or not (10 <= dur <= 28) or not (3 <= len(c["lines"]) <= 9):
            continue
        if c.get("quality", 0) < 4 or any(not l.get("en") for l in c["lines"]):
            continue
        if not os.path.exists(os.path.join(ROOT, "public/data/explain", f"{c['id']}.json")):
            continue
        ok.append(c)
    ok.sort(key=lambda c: (-prescore(c), c["id"]))
    per_video, per_channel, out = collections.Counter(), collections.Counter(), []
    for c in ok:
        ch = videos[c["videoId"]]["channel"]
        if per_video[c["videoId"]] >= 2 or per_channel[ch] >= 4:
            continue
        per_video[c["videoId"]] += 1
        per_channel[ch] += 1
        out.append(c)
        if len(out) >= limit:
            break
    by_id = {c["id"]: c for c in clips}
    if SHOWCASE in by_id and SHOWCASE not in {c["id"] for c in out}:
        out.insert(0, by_id[SHOWCASE])
    return out


def call(vid, windows):
    text = "\n".join(f'- id "{c["id"]}": {c["start"]:.1f}s to {c["end"]:.1f}s — "{c["title"]}"' for c in windows)
    body = {"model": MODEL, "messages": [{"role": "user", "content": [
        {"type": "video_url", "video_url": {"url": f"https://www.youtube.com/watch?v={vid}"}},
        {"type": "text", "text": PROMPT.format(windows=text)},
    ]}]}
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), headers={
        "Authorization": f"Bearer {os.environ['LOVABLE_API_KEY']}", "Content-Type": "application/json", "X-Lovable-AIG-SDK": "fetch"})
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())


def parse(text):
    text = re.sub(r"^```(?:json)?|```$", "", text.strip()).strip()
    return json.loads(text[text.find("{"): text.rfind("}") + 1])


def rate(item):
    vid, windows = item
    out = os.path.join(CACHE, f"{vid}.json")
    want = sorted(c["id"] for c in windows)
    if os.path.exists(out):
        cached = json.load(open(out, encoding="utf-8"))
        if sorted(cached.get("ids", [])) == want:
            return vid, "cached"
    last = None
    for attempt in range(3):
        try:
            res = call(vid, windows)
            data = parse(res["choices"][0]["message"]["content"])
            got = {r.get("id"): r for r in data.get("ratings", []) if r.get("id") in want}
            if not got:
                raise ValueError("no ratings for the listed windows")
            json.dump({"videoId": vid, "ids": want, "model": MODEL, "ratings": got}, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            return vid, f"ok {len(got)}"
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code} {e.read()[:200]!r}"
            if e.code not in (429, 500, 502, 503, 504):
                break
        except Exception as e:
            last = repr(e)[:200]
        time.sleep(8 * (attempt + 1))
    return vid, f"FAIL {last}"


def final_score(r):
    s = r["appeal"] * 1.0 + r["clarity"] * 0.9 + r["picture"] * 0.6 + r["ease"] * 0.8
    if r.get("english"):
        s -= 8
    s -= 2.5 * len([i for i in r.get("issues", []) if i])
    return s


def select(videos, cands, size, unplayable, pool_size=None, use_ai=False):
    by_id = {c["id"]: c for c in cands}
    scored = []
    for c in cands:
        f = os.path.join(CACHE, f"{c['videoId']}.json")
        if not os.path.exists(f) or c["id"] in unplayable:
            continue
        r = json.load(open(f, encoding="utf-8"))["ratings"].get(c["id"])
        if not r or not all(isinstance(r.get(k), (int, float)) for k in ("appeal", "clarity", "picture", "ease")):
            continue
        if r.get("english") or r["clarity"] < 4 or r["appeal"] < 7 or "unsafe content" in " ".join(r.get("issues", [])).lower():
            continue
        scored.append((final_score(r) + LEVEL_WEIGHT[c["level"]] * 0.5, c, r))
    scored.sort(key=lambda x: (-x[0], x[1]["id"]))
    picked, per_video, per_channel, per_level = [], set(), collections.Counter(), collections.Counter()
    level_cap = {"N5": size, "N4": int(size * 0.45), "N3": int(size * 0.2)}
    for s, c, r in scored:
        ch = videos[c["videoId"]]["channel"]
        if c["videoId"] in per_video or per_channel[ch] >= 2 or per_level[c["level"]] >= level_cap[c["level"]]:
            continue
        picked.append((s, c, r))
        per_video.add(c["videoId"])
        per_channel[ch] += 1
        per_level[c["level"]] += 1
        if len(picked) >= (pool_size or size):
            break
    head = [SHOWCASE] if SHOWCASE else []
    room = size - len(head)
    if use_ai and len(picked) > room:
        try:
            chosen = ai_order(videos, picked, room)
            by = {c["id"]: (sc, c, r) for sc, c, r in picked}
            seq = [by[o["id"]] for o in chosen if o["id"] in by and o["id"] != SHOWCASE]
            seen_ids, ordered = set(), []
            for e in seq:
                if e[1]["id"] not in seen_ids:
                    seen_ids.add(e[1]["id"])
                    ordered.append(e)
            for e in sorted(picked, key=lambda x: -x[0]):  # top up if the editor returned fewer
                if len(ordered) >= room:
                    break
                if e[1]["id"] not in seen_ids and e[1]["id"] != SHOWCASE:
                    seen_ids.add(e[1]["id"])
                    ordered.append(e)
            ordered = ordered[:room]
            ids = head + [c["id"] for _, c, _ in ordered]
            notes = {c["id"]: {"score": round(sc, 1), "level": c["level"], "title": c["title"], "channel": videos[c["videoId"]]["channel"], "why": r.get("why", "")} for sc, c, r in ordered}
            return ids, notes
        except Exception as e:  # editor pass is optional; fall back to score order
            print("editor order failed:", repr(e)[:200])
    # Order: best first, but never the same channel or the same main topic twice in a row.
    pool, ordered = sorted(picked, key=lambda x: -x[0]), []
    while pool:
        k = 0
        for i, (_, c, _) in enumerate(pool[:6]):
            prev = ordered[-1][1] if ordered else None
            if not prev or (videos[c["videoId"]]["channel"] != videos[prev["videoId"]]["channel"] and (c["topics"][:1] != prev["topics"][:1])):
                k = i
                break
        ordered.append(pool.pop(k))
    ids = head + [c["id"] for _, c, _ in ordered if c["id"] != SHOWCASE][:room]
    notes = {c["id"]: {"score": round(s, 1), "level": c["level"], "title": c["title"], "channel": videos[c["videoId"]]["channel"], "why": r.get("why", "")} for s, c, r in ordered}
    return ids, notes


ORDER_MODEL = os.environ.get("STARTER_ORDER_MODEL", "openai/gpt-6-astra")
ORDER_PROMPT = """You are the editor of a TikTok-style Japanese listening app. Below are clips that already
passed quality checks (an AI watched each one; all play in the official YouTube player).
Choose the {n} best and put them in the order a brand-new learner should see them in their
first sessions. Rules:
- Start with the most charming, easy and lively clips; first impressions matter most.
- Mix kinds all the time: real-life vlogs, animals, food, travel, animation/anime, family/kids,
  culture, everyday conversations. Never two clips of the same kind or channel back to back.
- Skip near-duplicates (e.g. several "dog asks for a snack" clips: keep the best one or two).
- Mostly N5; place the few N4 clips after position 12.
Return every chosen id exactly once with a short reason (max 12 words).

Clips:
{clips}"""
ORDER_SCHEMA = {"type": "object", "additionalProperties": False, "required": ["order"], "properties": {
    "order": {"type": "array", "items": {"type": "object", "additionalProperties": False, "required": ["id", "reason"],
                                         "properties": {"id": {"type": "string"}, "reason": {"type": "string"}}}}}}


def ai_order(videos, pool, n):
    """Editor pass over the verified pool (text only). Cached by pool content."""
    import hashlib
    lines = []
    for s_, c, r in pool:
        first = " / ".join(f"{l['ja']} ({l['en']})" for l in c["lines"][:3])
        lines.append(f'- id {c["id"]} | {c["level"]} | {c["end"] - c["start"]:.0f}s | {c["title"]} | channel: {videos[c["videoId"]]["channel"]} | topics: {",".join(c["topics"])} | rating: {r.get("why", "")} | lines: {first}')
    prompt = ORDER_PROMPT.format(n=n, clips="\n".join(lines))
    key = hashlib.sha1((ORDER_MODEL + prompt).encode()).hexdigest()[:16]
    cache = os.path.join(CACHE, f"_order-{key}.json")
    if os.path.exists(cache):
        return json.load(open(cache, encoding="utf-8"))["order"]
    body = {"model": ORDER_MODEL, "input": [{"role": "user", "content": prompt}], "stream": True, "store": False,
            "reasoning": {"effort": "medium"},
            "text": {"format": {"type": "json_schema", "name": "starter_order", "strict": True, "schema": ORDER_SCHEMA}}}
    req = urllib.request.Request("https://ai.gateway.lovable.dev/v1/responses", data=json.dumps(body).encode(), headers={
        "Lovable-API-Key": os.environ["LOVABLE_API_KEY"], "Content-Type": "application/json", "X-Lovable-AIG-SDK": "fetch"})
    text = []
    with urllib.request.urlopen(req, timeout=900) as r:
        for raw in r:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            ev = json.loads(data)
            if ev.get("type") == "response.output_text.delta":
                text.append(ev.get("delta", ""))
            elif ev.get("type") in ("response.failed", "error"):
                raise RuntimeError(str(ev)[:300])
    order = json.loads("".join(text))["order"]
    json.dump({"model": ORDER_MODEL, "order": order}, open(cache, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return order


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=24)
    ap.add_argument("--size", type=int, default=48)
    ap.add_argument("--select-only", action="store_true")
    ap.add_argument("--max", type=int, default=360, help="candidate windows to rate")
    ap.add_argument("--pool", type=int, default=0, help="verified pool size for the AI editor order (> size)")
    a = ap.parse_args()
    os.makedirs(CACHE, exist_ok=True)
    videos, clips = load()
    global SHOWCASE
    opening = sorted((c for c in clips if c["videoId"] == SHOWCASE_VIDEO), key=lambda c: c["start"])
    SHOWCASE = opening[0]["id"] if opening else None
    if not SHOWCASE:  # its video failed the timing check: the editor's first pick opens instead
        print(f"showcase video {SHOWCASE_VIDEO} has no clips now; the best-rated clip opens the starter")
    cands = candidates(videos, clips, a.max)
    print(f"candidates {len(cands)} from {len({c['videoId'] for c in cands})} videos", flush=True)
    if not a.select_only:
        groups = collections.defaultdict(list)
        for c in cands:
            groups[c["videoId"]].append(c)
        with cf.ThreadPoolExecutor(a.workers) as ex:
            for vid, status in ex.map(rate, groups.items()):
                if not status.startswith("cached"):
                    print(vid, status, flush=True)
    unplayable_file = os.path.join(HERE, "starter-unplayable.json")
    unplayable = set(json.load(open(unplayable_file))) if os.path.exists(unplayable_file) else set()  # ids (dict keys or list)
    ids, notes = select(videos, cands, a.size, unplayable, pool_size=a.pool, use_ai=a.pool > a.size)
    json.dump({"_about": "Curated starter feed (scripts/content/pick_starter.py). First id = the onboarding showcase (same for everyone). Do not hand-edit; re-run the script.",
               "ids": ids, "notes": notes}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    lv = collections.Counter(n["level"] for n in notes.values())
    print(f"starter {len(ids)} clips, levels {dict(lv)}, channels {len({n['channel'] for n in notes.values()})}")


if __name__ == "__main__":
    main()
