#!/usr/bin/env python3
"""Find more candidate videos from channels that already produced good beginner clips.

Reads the public channel "Videos" page (metadata only — no media is fetched), lists
videos not yet in picks.txt with their length, and checks embeddability via YouTube's
oEmbed endpoint. Output: JSON lines on stdout {id, title, channel, seconds, embeddable}.

Usage: python3 scripts/content/discover_channels.py "Channel name" [...] [--max 15] [--maxlen 900]
"""
import argparse, json, os, re, sys, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36", "Accept-Language": "en-US,en;q=0.8,ja;q=0.6"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40) as r:
        return r.read().decode("utf-8", "replace")


def initial_data(html):
    m = re.search(r"var ytInitialData = (\{.*?\});</script>", html, re.S) or re.search(r"ytInitialData\"?\]? = (\{.*?\});", html, re.S)
    return json.loads(m.group(1)) if m else {}


def walk(o):
    if isinstance(o, dict):
        yield o
        for v in o.values():
            yield from walk(v)
    elif isinstance(o, list):
        for v in o:
            yield from walk(v)


def secs(text):
    parts = [int(p) for p in re.findall(r"\d+", text or "")]
    total = 0
    for p in parts:
        total = total * 60 + p
    return total


def videos_of(channel_url):
    data = initial_data(get(channel_url.rstrip("/") + "/videos"))
    out, seen = [], set()
    for node in walk(data):
        vr = node.get("videoRenderer")
        if vr and vr.get("videoId") not in seen:
            seen.add(vr["videoId"])
            title = "".join(r.get("text", "") for r in vr.get("title", {}).get("runs", []))
            out.append((vr["videoId"], title, secs(vr.get("lengthText", {}).get("simpleText", ""))))
        lv = node.get("lockupViewModel")
        if lv and lv.get("contentId") and lv["contentId"] not in seen:
            seen.add(lv["contentId"])
            meta = lv.get("metadata", {}).get("lockupMetadataViewModel", {})
            title = meta.get("title", {}).get("content", "")
            length = ""
            for n in walk(lv.get("contentImage", {})):
                t = n.get("text")
                if isinstance(t, str) and re.fullmatch(r"\d+(:\d\d)+", t):
                    length = t
            out.append((lv["contentId"], title, secs(length)))
    return out


def embeddable(vid):
    try:
        get("https://www.youtube.com/oembed?format=json&url=" + urllib.parse.quote(f"https://www.youtube.com/watch?v={vid}"))
        return True
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("channels", nargs="+")
    ap.add_argument("--max", type=int, default=15)
    ap.add_argument("--maxlen", type=int, default=900)
    ap.add_argument("--minlen", type=int, default=60)
    a = ap.parse_args()
    picked = {l.split()[0] for l in open(os.path.join(ROOT, "picks.txt"), encoding="utf-8") if l.strip() and not l.startswith("#")}
    meta = json.load(open(os.path.join(ROOT, "videos.json"), encoding="utf-8"))
    urls = {}
    for v in meta.values():
        urls.setdefault(v["channel"], v["channelUrl"])
    for ch in a.channels:
        url = urls.get(ch, ch)
        try:
            vids = videos_of(url)
        except Exception as e:
            print(json.dumps({"channel": ch, "error": str(e)}), flush=True)
            continue
        n = 0
        for vid, title, s in vids:
            if vid in picked or not (a.minlen <= s <= a.maxlen):
                continue
            ok = embeddable(vid)
            print(json.dumps({"id": vid, "title": title, "channel": ch, "seconds": s, "embeddable": ok}, ensure_ascii=False), flush=True)
            n += ok
            if n >= a.max:
                break


if __name__ == "__main__":
    main()
