#!/usr/bin/env python3
"""Checks that clips really play through YouTube's official embedded player (IFrame API).

For each clip id: load the official player (youtube-nocookie host, muted), read the real video
length, confirm the clip window fits inside it, start playback at the clip start and confirm the
playhead actually moves inside the window. Nothing is downloaded; it is the same player the apps use.

Usage: python3 scripts/content/verify_playable.py ID [ID ...] [--out file.json] [--workers 6]
Prints one line per clip and writes the failing ids (with reasons) to --out.
"""
import argparse, asyncio, json, os, sys

from playwright.async_api import async_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))

PAGE = """<!doctype html><html><body style="margin:0;background:#000">
<div id="p"></div>
<script>
window.result = null;
function onYouTubeIframeAPIReady() {
  const q = new URLSearchParams(location.hash.slice(1));
  const start = parseFloat(q.get('s')), end = parseFloat(q.get('e'));
  const t0 = performance.now();
  let readyAt = 0, moved = false;
  const p = new YT.Player('p', { videoId: q.get('v'), width: 480, height: 270, host: 'https://www.youtube-nocookie.com',
    playerVars: { start: Math.floor(start), end: Math.ceil(end) + 1, autoplay: 1, mute: 1, controls: 0, playsinline: 1, rel: 0 },
    events: {
      onReady: (e) => { readyAt = performance.now() - t0; e.target.mute(); e.target.seekTo(start, true); e.target.playVideo(); },
      onError: (e) => { window.result = { ok: false, reason: 'player error ' + e.data }; },
    } });
  const id = setInterval(() => {
    if (window.result) return clearInterval(id);
    if (!readyAt) return;
    const d = p.getDuration ? p.getDuration() : 0;
    const t = p.getCurrentTime ? p.getCurrentTime() : 0;
    if (d > 0 && (start >= d || end > d + 0.75)) { window.result = { ok: false, reason: 'window ' + start + '-' + end + ' outside video length ' + d }; return; }
    if (d > 0 && t >= start + 1 && t <= end + 2) { window.result = { ok: true, duration: d, readyMs: Math.round(readyAt), playingMs: Math.round(performance.now() - t0) }; }
  }, 200);
}
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body></html>"""


def load_clips():
    meta = json.load(open(os.path.join(ROOT, "public/data/content.json"), encoding="utf-8"))
    clips = [c for p in meta["parts"] for c in json.load(open(os.path.join(ROOT, "public/data", p), encoding="utf-8"))["clips"]]
    return {c["id"]: c for c in clips}


async def check(ctx, clip, server):
    page = await ctx.new_page()
    try:
        await page.goto(f"{server}#v={clip['videoId']}&s={clip['start']}&e={clip['end']}", wait_until="domcontentloaded")
        for _ in range(150):  # up to 30 s
            r = await page.evaluate("window.result")
            if r:
                return r
            await page.wait_for_timeout(200)
        return {"ok": False, "reason": "did not start playing within 30 s"}
    finally:
        await page.close()


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--from-json", help="JSON file with an 'ids' list")
    ap.add_argument("--out", default=os.path.join(HERE, "starter-unplayable.json"))
    ap.add_argument("--workers", type=int, default=6)
    a = ap.parse_args()
    ids = list(a.ids)
    if a.from_json:
        ids += json.load(open(a.from_json))["ids"]
    clips = load_clips()
    html_path = "/tmp/yt_verify.html"
    open(html_path, "w").write(PAGE)
    # The IFrame API needs an http(s) origin; serve the page from a tiny local server.
    import http.server, threading, functools
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory="/tmp")
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    server = f"http://127.0.0.1:{srv.server_address[1]}/yt_verify.html"
    bad = json.load(open(a.out)) if os.path.exists(a.out) else {}
    if isinstance(bad, list):
        bad = {i: "unplayable" for i in bad}
    sem = asyncio.Semaphore(a.workers)
    async with async_playwright() as p:
        b = await p.chromium.launch(headless=True, args=["--autoplay-policy=no-user-gesture-required"])
        ctx = await b.new_context(viewport={"width": 640, "height": 400})

        async def one(cid):
            c = clips.get(cid)
            if not c:
                return cid, {"ok": False, "reason": "not in content"}
            async with sem:
                r = await check(ctx, c, server)
                if not r.get("ok"):  # one retry for network hiccups
                    r = await check(ctx, c, server)
                return cid, r

        results = await asyncio.gather(*[one(i) for i in ids])
        await b.close()
    srv.shutdown()
    for cid, r in results:
        print(("OK  " if r.get("ok") else "BAD ") + cid, json.dumps(r), flush=True)
        if r.get("ok"):
            bad.pop(cid, None)
        else:
            bad[cid] = r.get("reason", "unplayable")
    json.dump(bad, open(a.out, "w"), indent=1, sort_keys=True)
    ok = sum(1 for _, r in results if r.get("ok"))
    print(f"playable {ok}/{len(results)}")


if __name__ == "__main__":
    asyncio.run(main())
