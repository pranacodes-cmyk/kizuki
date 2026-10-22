"""Shared helpers for the Google Play Developer API and the App Store Connect API.

Credentials come only from environment variables (never written to disk or printed):
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON   service-account JSON with access to the Play app
  APPLE_KEY_ID, APPLE_ISSUER_ID, APPLE_P8_PRIVATE_KEY   App Store Connect API (Admin) key
"""
import json
import os
import time

import jwt
import requests

PACKAGE = "com.kizukijapan.app"
BUNDLE_ID = "com.kizukijapan.app"

# ---------------------------------------------------------------- Google Play

_play_token = {"value": None, "exp": 0}


def play_token():
    if _play_token["value"] and time.time() < _play_token["exp"] - 60:
        return _play_token["value"]
    sa = json.loads(os.environ["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"])
    now = int(time.time())
    assertion = jwt.encode({
        "iss": sa["client_email"],
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now, "exp": now + 3600,
    }, sa["private_key"], algorithm="RS256")
    r = requests.post("https://oauth2.googleapis.com/token", data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}, timeout=60)
    r.raise_for_status()
    _play_token.update(value=r.json()["access_token"], exp=now + 3500)
    return _play_token["value"]


PLAY = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
PLAY_UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"


def play(method, path, body=None, base=PLAY, ok=(200, 204), **kw):
    r = requests.request(method, base + path, json=body, timeout=600,
                         headers={"Authorization": f"Bearer {play_token()}"}, **kw)
    if r.status_code not in ok:
        raise RuntimeError(f"Play {method} {path} -> {r.status_code}: {r.text[:1500]}")
    return r.json() if r.content else None


# ---------------------------------------------------------------- App Store Connect

ASC = "https://api.appstoreconnect.apple.com"


def asc_token():
    key = os.environ["APPLE_P8_PRIVATE_KEY"].strip()
    if "BEGIN PRIVATE KEY" not in key:
        key = "-----BEGIN PRIVATE KEY-----\n" + key + "\n-----END PRIVATE KEY-----"
    key = key.replace("\\n", "\n")
    now = int(time.time())
    return jwt.encode({"iss": os.environ["APPLE_ISSUER_ID"].strip(), "iat": now, "exp": now + 1100,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256",
                      headers={"kid": os.environ["APPLE_KEY_ID"].strip(), "typ": "JWT"})


def asc(method, path, body=None, ok=(200, 201, 204), params=None):
    url = path if path.startswith("http") else ASC + path
    r = requests.request(method, url, json=body, params=params, timeout=300,
                         headers={"Authorization": f"Bearer {asc_token()}", "Content-Type": "application/json"})
    if r.status_code not in ok:
        raise RuntimeError(f"ASC {method} {path} -> {r.status_code}: {r.text[:2000]}")
    return r.json() if r.content else None


def asc_app():
    d = asc("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})
    if not d["data"]:
        raise RuntimeError("no App Store Connect app for " + BUNDLE_ID)
    return d["data"][0]
