#!/usr/bin/env python3
"""Store GitHub Actions repository secrets (encrypted with the repo's public key).

Usage: GITHUB_TOKEN=... python3 scripts/github/set_secrets.py OWNER/REPO NAME=@/path/file NAME=env:VAR NAME=b64:/path/file ...
  @/path      secret value = file contents
  b64:/path   secret value = base64 of the file (binary files such as .p12)
  env:VAR     secret value = environment variable VAR
Values are never printed.
"""
import base64
import os
import sys

import requests
from nacl import encoding, public

API = "https://api.github.com"
H = {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}", "Accept": "application/vnd.github+json"}


def value_of(spec):
    if spec.startswith("@"):
        return open(spec[1:]).read()
    if spec.startswith("b64:"):
        return base64.b64encode(open(spec[4:], "rb").read()).decode()
    if spec.startswith("env:"):
        return os.environ[spec[4:]]
    raise SystemExit("value must be @file, b64:file or env:VAR")


def main():
    repo = sys.argv[1]
    key = requests.get(f"{API}/repos/{repo}/actions/secrets/public-key", headers=H, timeout=60).json()
    box = public.SealedBox(public.PublicKey(key["key"].encode(), encoding.Base64Encoder()))
    for arg in sys.argv[2:]:
        name, spec = arg.split("=", 1)
        sealed = base64.b64encode(box.encrypt(value_of(spec).encode())).decode()
        r = requests.put(f"{API}/repos/{repo}/actions/secrets/{name}", headers=H, timeout=60,
                         json={"encrypted_value": sealed, "key_id": key["key_id"]})
        print(name, "saved" if r.status_code in (201, 204) else f"FAILED {r.status_code} {r.text[:200]}")


if __name__ == "__main__":
    main()
