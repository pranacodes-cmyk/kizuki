#!/usr/bin/env python3
"""Library-wide check through YouTube's official embedded player (IFrame API, muted, nothing downloaded).

For every video in public/data: does it play inside an embed, and how long is it really?
Results are cached in scripts/content/playable.json (re-runs only check new videos; --recheck
forces all). Then every clip whose window starts past the real end, or whose video refuses to
play embedded, is written to scripts/content/excluded-clips.json with the reason, and embed-
blocked videos go to scripts/content/blocklist.txt — build.ts / apply-exclusions.ts then drop them
from both apps.

Usage: python3 scripts/content/verify_library.py [--workers 10] [--recheck] [--apply]
"""
import argparse, asyncio, datetime, functools, http.server, json, os, threading

from playwright.async_api import async_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
CACHE = os.path.join(HERE, "playable.json")
EXCLUDED = os.path.join(HERE, "excluded-clips.json")
BLOCKLIST = os.path.join(HERE, "blocklist.txt")
EMBED_ERRORS = {100: "video removed or private", 101: "owner does not allow embedding", 150: "owner does not allow embedding"}

PAGE = """<!doctype html><html><body style="margin:0;background:#000"><div id="p"></div>
<script>
window.result = null;
function onYouTubeIframeAPIReady() {
  const v = location.hash.slice(1);
  const p = new YT.Player('p', { videoId: v, width: 480, height: 270, host: 'https://www.youtube-nocookie.com',
    playerVars: { autoplay: 1, mute: 1, controls: 0, playsinline: 1, rel: 0 },
    events: {
      onReady: (e) => { e.target.mute(); e.target.playVideo(); },
      onError: (e) => { window.result = { error: e.data }; },
    } });
  const id = setInterval(() => {
    if (window.result) return clearInterval(id);
    const d = p.getDuration ? p.getDuration() : 0;
    const st = p.getPlayerState ? p.getPlayerState() : -1;
    if (d > 0 && (st === 1 || st === 3 || st === 2)) window.result = { duration: d };
  }, 250);
}
</script><script src="https://www.youtube.com/iframe_api"></script></body></html>"""


def load():
    meta = json.load(open(os.path.join(ROOT, "public/data/content.json"), encoding="utf-8"))
    clips = [c for p in meta["parts"] for c in json.load(open(os.path.join(ROOT, "public/data", p), encoding="utf-8"))["clips"]]
    return meta["videos"], clips


async def probe(ctx, vid, server):
    page = await ctx.new_page()
    try:
        await page.goto(f"{server}#{vid}", wait_until="domcontentloaded")
        for _ in range(100):  # 25 s
            r = await page.evaluate("window.result")
            if r:
                return r
            await page.wait_for_timeout(250)
        return {"timeout": True}
    finally:
        await page.close()


async def check_all(vids, workers):
    open("/tmp/yt_library.html", "w").write(PAGE)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(http.server.SimpleHTTPRequestHandler, directory="/tmp"))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    server = f"http://127.0.0.1:{srv.server_address[1]}/yt_library.html"
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    sem = asyncio.Semaphore(workers)
    today = datetime.date.today().isoformat()
    done = 0
    async with async_playwright() as p:
        b = await p.chromium.launch(headless=True, args=["--autoplay-policy=no-user-gesture-required"])
        ctx = await b.new_context(viewport={"width": 640, "height": 400})

        async def one(vid):
            nonlocal done
            async with sem:
                r = await probe(ctx, vid, server)
                if r.get("timeout"):
                    r = await probe(ctx, vid, server)
            r["checked"] = today
            cache[vid] = r
            done += 1
            if done % 50 == 0:
                json.dump(cache, open(CACHE, "w"), indent=0, sort_keys=True)
                print(f"checked {done}/{len(vids)}", flush=True)

        await asyncio.gather(*[one(v) for v in vids])
        await b.close()
    srv.shutdown()
    json.dump(cache, open(CACHE, "w"), indent=0, sort_keys=True)
    return cache


def apply(videos, clips, cache):
    excluded = json.load(open(EXCLUDED, encoding="utf-8")) if os.path.exists(EXCLUDED) else {}
    blocked = set(open(BLOCKLIST).read().split()) if os.path.exists(BLOCKLIST) else set()
    added_clips, added_videos = 0, 0
    # A video with ANY window past its real end has a stretched AI timeline (median 1.3x when
    # this was found): its in-range windows are mistimed too, so the whole video is excluded
    # until find_clips.py regenerates it with the real length (scripts/content/regenerate.json).
    suspect = {}
    for c in clips:
        d = (cache.get(c["videoId"]) or {}).get("duration") or 0
        if d > 0 and (c["start"] >= d or c["end"] > d + 0.75):
            suspect[c["videoId"]] = d
    for c in clips:
        r = cache.get(c["videoId"]) or {}
        when = r.get("checked", "")
        if r.get("error") in EMBED_ERRORS:
            if c["videoId"] not in blocked:
                blocked.add(c["videoId"])
                added_videos += 1
            continue
        d = r.get("duration") or 0
        if c["id"] in excluded:
            continue
        if d > 0 and (c["start"] >= d or c["end"] > d + 0.75):
            excluded[c["id"]] = f"Official player reports the video is {d:.0f} s long ({when}); this generated window {c['start']:.1f}-{c['end']:.1f} s is outside it."
            added_clips += 1
        elif c["videoId"] in suspect:
            excluded[c["id"]] = f"Same video has windows past its real {d:.0f} s length ({when}): stretched AI timeline, this window is likely mistimed."
            added_clips += 1
    json.dump(dict(sorted(excluded.items())), open(EXCLUDED, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(BLOCKLIST, "w").write("\n".join(sorted(blocked)) + "\n")
    json.dump(sorted(suspect), open(os.path.join(HERE, "regenerate.json"), "w"), indent=0)
    print(f"excluded clips +{added_clips} (total {len(excluded)}), blocked videos +{added_videos} (total {len(blocked)}), stretched-timeline videos {len(suspect)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=10)
    ap.add_argument("--recheck", action="store_true")
    ap.add_argument("--apply", action="store_true", help="write exclusions + blocklist from the cache")
    a = ap.parse_args()
    videos, clips = load()
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    vids = sorted({c["videoId"] for c in clips})
    todo = vids if a.recheck else [v for v in vids if v not in cache or cache[v].get("timeout")]
    print(f"videos {len(vids)}, to check {len(todo)}", flush=True)
    if todo:
        cache = asyncio.run(check_all(todo, a.workers))
    errs = {}
    for v in vids:
        r = cache.get(v, {})
        k = "error " + str(r["error"]) if "error" in r else "timeout" if r.get("timeout") else "ok"
        errs[k] = errs.get(k, 0) + 1
    print("results", errs)
    if a.apply:
        apply(videos, clips, cache)


if __name__ == "__main__":
    main()
