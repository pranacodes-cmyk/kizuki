#!/usr/bin/env python3
"""Find candidate videos through YouTube's public search page (metadata only, no media).

Each query line in a queries file is "topic,topic | search words". Results are filtered by
length, de-duplicated against picks.txt, and written as JSON lines to the output file:
{id, title, channel, channelId, seconds, topics, query}. Embeddability is checked later.

Usage: python3 scripts/content/discover_search.py queries.txt out.jsonl [--per 25]
"""
import argparse, concurrent.futures as cf, json, os, re, sys, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from discover_channels import get, initial_data, walk, secs  # noqa: E402

ROOT = os.path.dirname(os.path.abspath(__file__))


def search(q):
    # sp=EgIQAQ%3D%3D = videos only
    html = get("https://www.youtube.com/results?sp=EgIQAQ%253D%253D&search_query=" + urllib.parse.quote(q))
    out = []
    for node in walk(initial_data(html)):
        vr = node.get("videoRenderer")
        if not vr:
            continue
        owner = (vr.get("ownerText") or vr.get("longBylineText") or {}).get("runs", [{}])[0]
        out.append({
            "id": vr["videoId"],
            "title": "".join(r.get("text", "") for r in vr.get("title", {}).get("runs", [])),
            "channel": owner.get("text", ""),
            "channelId": owner.get("navigationEndpoint", {}).get("browseEndpoint", {}).get("browseId", ""),
            "seconds": secs(vr.get("lengthText", {}).get("simpleText", "")),
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("queries")
    ap.add_argument("out")
    ap.add_argument("--per", type=int, default=25)
    ap.add_argument("--minlen", type=int, default=60)
    ap.add_argument("--maxlen", type=int, default=1200)
    a = ap.parse_args()
    seen = {l.split()[0] for l in open(os.path.join(ROOT, "picks.txt"), encoding="utf-8") if l.strip() and not l.startswith("#")}
    qs = []
    for line in open(a.queries, encoding="utf-8"):
        if "|" in line and not line.startswith("#"):
            t, q = line.split("|", 1)
            qs.append((t.strip().split(","), q.strip()))

    def run(item):
        topics, q = item
        try:
            return topics, q, search(q)
        except Exception as e:
            print("ERR", q, e, file=sys.stderr)
            return topics, q, []

    n = 0
    with open(a.out, "a", encoding="utf-8") as f, cf.ThreadPoolExecutor(6) as ex:
        for topics, q, res in ex.map(run, qs):
            k = 0
            for r in res:
                if r["id"] in seen or not (a.minlen <= r["seconds"] <= a.maxlen):
                    continue
                seen.add(r["id"])
                f.write(json.dumps({**r, "topics": topics, "query": q}, ensure_ascii=False) + "\n")
                k += 1
                n += 1
                if k >= a.per:
                    break
    print("candidates", n)


if __name__ == "__main__":
    main()
