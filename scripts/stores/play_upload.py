#!/usr/bin/env python3
"""Upload an Android App Bundle to a Google Play track.

Usage: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=... python3 scripts/stores/play_upload.py app.aab [track] [status] [release-name]
Defaults: track=internal, status=draft (a never-published app only accepts draft releases).
Prints the version code Play recorded.
"""
import sys

from common import PLAY_UPLOAD, play


def main():
    aab = sys.argv[1]
    track = sys.argv[2] if len(sys.argv) > 2 else "internal"
    status = sys.argv[3] if len(sys.argv) > 3 else "draft"
    name = sys.argv[4] if len(sys.argv) > 4 else None
    edit = play("POST", "/edits", {})["id"]
    with open(aab, "rb") as f:
        bundle = _upload(edit, f)
    code = bundle["versionCode"]
    print("uploaded versionCode", code)
    release = {"versionCodes": [str(code)], "status": status}
    if name:
        release["name"] = name
    play("PUT", f"/edits/{edit}/tracks/{track}", {"track": track, "releases": [release]})
    play("POST", f"/edits/{edit}:commit")
    print(f"committed: {track} track, {status} release, versionCode {code}")


def _upload(edit, f):
    import requests
    from common import play_token
    r = requests.post(f"{PLAY_UPLOAD}/edits/{edit}/bundles", params={"uploadType": "media"}, data=f, timeout=1800,
                      headers={"Authorization": f"Bearer {play_token()}", "Content-Type": "application/octet-stream"})
    if r.status_code != 200:
        raise SystemExit(f"bundle upload failed {r.status_code}: {r.text[:1500]}")
    return r.json()


if __name__ == "__main__":
    main()
