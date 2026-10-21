#!/usr/bin/env python3
"""Small GitHub Actions helper for the Kizuki repo (reads GITHUB_TOKEN from the env).

  ci.py OWNER/REPO status            latest workflow runs + job/step states
  ci.py OWNER/REPO wait [RUN_ID]     poll until the run finishes (max ~9 min per call)
  ci.py OWNER/REPO logs RUN_ID JOB   print the tail of a job's log
  ci.py OWNER/REPO artifacts RUN_ID DEST   download + unzip all artifacts of a run
  ci.py OWNER/REPO dispatch          start the Android APK workflow on main
"""
import io
import os
import sys
import time
import zipfile

import requests

API = "https://api.github.com"
TOKEN = os.environ["GITHUB_TOKEN"]


def req(path, method="GET", body=None, raw=False):
    # requests drops the Authorization header on cross-host redirects (log/artifact
    # downloads redirect to signed storage URLs that reject it).
    url = path if path.startswith("http") else API + path
    r = requests.request(method, url, json=body, timeout=180, headers={
        "Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github+json"})
    r.raise_for_status()
    if raw:
        return r.content
    return r.json() if r.content else None


def latest(repo):
    return req(f"/repos/{repo}/actions/runs?per_page=5")["workflow_runs"]


def show(repo, run):
    print(f"run {run['id']} [{run['status']}/{run['conclusion']}] {run['head_sha'][:7]} {run['display_title'][:60]}")
    for j in req(f"/repos/{repo}/actions/runs/{run['id']}/jobs")["jobs"]:
        print(f"  job {j['id']} {j['name']}: {j['status']}/{j['conclusion']}")
        for s in j.get("steps", []):
            if s["status"] != "completed" or s["conclusion"] not in ("success", "skipped"):
                print(f"     - {s['name']}: {s['status']}/{s['conclusion']}")


def main():
    repo, cmd = sys.argv[1], sys.argv[2]
    if cmd == "status":
        runs = latest(repo)
        if not runs:
            print("no runs yet")
        for run in runs[:2]:
            show(repo, run)
    elif cmd == "wait":
        run_id = sys.argv[3] if len(sys.argv) > 3 else latest(repo)[0]["id"]
        end = time.time() + 540
        while time.time() < end:
            run = req(f"/repos/{repo}/actions/runs/{run_id}")
            if run["status"] == "completed":
                break
            time.sleep(20)
        show(repo, run)
    elif cmd == "logs":
        run_id, job_name = sys.argv[3], sys.argv[4]
        jobs = req(f"/repos/{repo}/actions/runs/{run_id}/jobs")["jobs"]
        job = next(j for j in jobs if job_name in j["name"])
        text = req(f"/repos/{repo}/actions/jobs/{job['id']}/logs", raw=True).decode(errors="replace")
        lines = text.splitlines()
        n = int(sys.argv[5]) if len(sys.argv) > 5 else 120
        print("\n".join(lines[-n:]))
    elif cmd == "artifacts":
        run_id, dest = sys.argv[3], sys.argv[4]
        os.makedirs(dest, exist_ok=True)
        for a in req(f"/repos/{repo}/actions/runs/{run_id}/artifacts")["artifacts"]:
            blob = req(a["archive_download_url"], raw=True)
            target = os.path.join(dest, a["name"])
            zipfile.ZipFile(io.BytesIO(blob)).extractall(target)
            print(f"{a['name']} -> {target} ({a['size_in_bytes']} bytes)")
    elif cmd == "dispatch":
        req(f"/repos/{repo}/actions/workflows/android-apk.yml/dispatches", "POST", {"ref": "main"})
        print("dispatched")


if __name__ == "__main__":
    main()
