#!/usr/bin/env python3
"""Mirror this project's tracked files to a GitHub repository through the REST API.

Usage: GITHUB_TOKEN=... python3 scripts/github/sync_to_github.py OWNER/REPO "commit message"

Creates the repository (public) if it doesn't exist, uploads only blobs GitHub doesn't
have yet, writes one commit whose tree is exactly `git ls-files` (so deletions carry
over) and moves `main` to it. Prints the new commit SHA.
"""
import base64
import concurrent.futures as cf
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.github.com"
TOKEN = os.environ.get("GITHUB_TOKEN")
ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()


def call(method, path, body=None, ok=(200, 201), tries=5):
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(tries):
        req = urllib.request.Request(API + path, data=data, method=method)
        req.add_header("Authorization", f"Bearer {TOKEN}")
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("X-GitHub-Api-Version", "2022-11-28")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as e:
            raw = e.read().decode(errors="replace")
            if e.code in ok:
                return e.code, json.loads(raw) if raw else None
            if e.code in (403, 429, 500, 502, 503, 504) and attempt < tries - 1:
                time.sleep(2 ** attempt * 3)
                continue
            return e.code, {"error": raw[:500]}
        except Exception as e:  # network hiccup
            if attempt < tries - 1:
                time.sleep(2 ** attempt * 2)
                continue
            raise
    return 0, None


def blob_sha(content: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(content) + content).hexdigest()


def main():
    if not TOKEN:
        sys.exit("GITHUB_TOKEN is not set")
    repo, message = sys.argv[1], sys.argv[2]
    owner, name = repo.split("/")

    status, info = call("GET", f"/repos/{repo}", ok=(200, 404))
    if status == 404:
        status, info = call("POST", "/user/repos", {
            "name": name, "private": False, "auto_init": True,
            "description": "Kizuki — learn Japanese from real clips (Flutter Android app + web prototype)",
        })
        if status != 201:
            sys.exit(f"could not create repo: {status} {info}")
        time.sleep(3)
        print(f"created https://github.com/{repo}")
    branch = "main"

    status, ref = call("GET", f"/repos/{repo}/git/ref/heads/{branch}")
    if status != 200:
        sys.exit(f"no {branch} branch: {status} {ref}")
    head = ref["object"]["sha"]
    _, commit = call("GET", f"/repos/{repo}/git/commits/{head}")
    _, tree = call("GET", f"/repos/{repo}/git/trees/{commit['tree']['sha']}?recursive=1")
    remote = {t["path"]: t["sha"] for t in tree.get("tree", []) if t["type"] == "blob"}

    # Tracked files with their modes (keeps gradlew & scripts executable).
    listing = subprocess.check_output(["git", "ls-files", "-s", "-z"], cwd=ROOT).decode().split("\0")
    entries = []
    for row in listing:
        if not row:
            continue
        meta, path = row.split("\t", 1)
        mode = meta.split()[0]
        full = os.path.join(ROOT, path)
        if not os.path.isfile(full):
            continue
        if path.startswith(".github/scripts/") and path.endswith(".sh"):
            mode = "100755"
        with open(full, "rb") as fh:
            content = fh.read()
        entries.append((path, mode, content, blob_sha(content)))

    missing = [e for e in entries if remote.get(e[0]) != e[3]]
    print(f"{len(entries)} files, {len(missing)} new or changed")
    changed = bool(missing)

    # Text files ride inside throwaway tree requests (one request creates ~150 blobs), which keeps
    # big content updates under GitHub's limit on content-creating requests; binaries use the blob API.
    seen, text, binary = set(), [], []
    for e in missing:
        if e[3] in seen:
            continue
        seen.add(e[3])
        try:
            e[2].decode("utf-8")
            (text if len(e[2]) < 900_000 else binary).append(e)
        except UnicodeDecodeError:
            binary.append(e)
    print(f"  {len(text)} text + {len(binary)} binary unique blobs to create")
    for i in range(0, len(text), 150):
        batch = text[i:i + 150]
        status, res = call("POST", f"/repos/{repo}/git/trees", {
            "tree": [{"path": f"f{j}", "mode": "100644", "type": "blob", "content": e[2].decode("utf-8")} for j, e in enumerate(batch)],
        }, tries=6)
        if status != 201:
            raise RuntimeError(f"text batch failed: {status} {str(res)[:300]}")
        print(f"  text blobs {min(i + 150, len(text))}/{len(text)}")
    missing = binary

    def upload(e):
        path, _, content, sha = e
        status, res = call("POST", f"/repos/{repo}/git/blobs", {"content": base64.b64encode(content).decode(), "encoding": "base64"})
        if status != 201 or res.get("sha") != sha:
            raise RuntimeError(f"blob upload failed for {path}: {status} {res}")
        return path

    with cf.ThreadPoolExecutor(max_workers=4) as pool:
        for i, _ in enumerate(pool.map(upload, missing), 1):
            if i % 200 == 0:
                print(f"  uploaded {i}/{len(missing)}")

    if not changed and set(remote) == {e[0] for e in entries}:
        print(f"nothing to commit; main is {head}")
        print(head)
        return

    status, new_tree = call("POST", f"/repos/{repo}/git/trees", {
        "tree": [{"path": p, "mode": m, "type": "blob", "sha": s} for p, m, _, s in entries],
    })
    if status != 201:
        sys.exit(f"tree failed: {status} {new_tree}")
    status, new_commit = call("POST", f"/repos/{repo}/git/commits", {"message": message, "tree": new_tree["sha"], "parents": [head]})
    if status != 201:
        sys.exit(f"commit failed: {status} {new_commit}")
    status, res = call("PATCH", f"/repos/{repo}/git/refs/heads/{branch}", {"sha": new_commit["sha"], "force": False})
    if status != 200:
        sys.exit(f"ref update failed: {status} {res}")
    print(new_commit["sha"])


if __name__ == "__main__":
    main()
