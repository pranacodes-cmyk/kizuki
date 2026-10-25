"""Creates iOS yearly trial-experiment variants (3-day trial, no trial) mirroring kizuki_premium_yearly.

Re-runnable: existing subscriptions/prices/offers are reused. Run from scripts/stores.
"""
import json
import sys

import common as c

APP = "6825872851"
GROUP = "22504518"
BASE = "6825873856"
VARIANTS = [
    {"productId": "kizuki_premium_yearly_3d", "name": "Kizuki Premium Yearly 3-day trial", "trial": "THREE_DAYS"},
    {"productId": "kizuki_premium_yearly_nt", "name": "Kizuki Premium Yearly no trial", "trial": None},
]


def all_pages(path, params):
    out, inc, url = [], [], path
    while url:
        d = c.asc("GET", url, params=params if url == path else None)
        out += d["data"]
        inc += d.get("included", [])
        url = d.get("links", {}).get("next")
    return out, inc


def base_prices():
    data, inc = all_pages(f"/v1/subscriptions/{BASE}/prices",
                          {"limit": 200, "include": "subscriptionPricePoint,territory"})
    pp = {i["id"]: i["attributes"]["customerPrice"] for i in inc if i["type"] == "subscriptionPricePoints"}
    return {d["relationships"]["territory"]["data"]["id"]: pp[d["relationships"]["subscriptionPricePoint"]["data"]["id"]]
            for d in data}


def ensure_sub(v):
    subs = c.asc("GET", f"/v1/subscriptionGroups/{GROUP}/subscriptions", params={"limit": 50})["data"]
    for s in subs:
        if s["attributes"]["productId"] == v["productId"]:
            return s["id"]
    s = c.asc("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
        "name": v["name"], "productId": v["productId"], "subscriptionPeriod": "ONE_YEAR", "familySharable": False,
        "reviewNote": "Unlocks unlimited clips, word explanations and Ask Kizuki.", "groupLevel": 1},
        "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": GROUP}}}}})
    sid = s["data"]["id"]
    c.asc("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations", "attributes": {
        "name": "Kizuki Premium Yearly", "locale": "en-US", "description": "Unlimited clips, explanations and Ask Kizuki"},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
    c.asc("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                          "availableTerritories": {"data": [{"type": "territories", "id": t} for t in PRICES]}}}})
    print("created", v["productId"], sid)
    return sid


def ensure_prices(sid):
    have, _ = all_pages(f"/v1/subscriptions/{sid}/prices", {"limit": 200, "include": "territory"})
    done = {d["relationships"]["territory"]["data"]["id"] for d in have}
    todo = [t for t in PRICES if t not in done]
    for t in todo:
        pts, _ = all_pages(f"/v1/subscriptions/{sid}/pricePoints", {"filter[territory]": t, "limit": 8000})
        match = [p for p in pts if p["attributes"]["customerPrice"] == PRICES[t]]
        if not match:
            print("  no price point", t, PRICES[t]); continue
        c.asc("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": False},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                              "territory": {"data": {"type": "territories", "id": t}},
                              "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": match[0]["id"]}}}}})
    print(" prices", sid, "existing", len(done), "added", len(todo))


def ensure_trial(sid, dur):
    have, inc = all_pages(f"/v1/subscriptions/{sid}/introductoryOffers", {"limit": 200, "include": "territory"})
    done = {d["relationships"]["territory"]["data"]["id"] for d in have if d["relationships"]["territory"].get("data")}
    for t in [t for t in PRICES if t not in done]:
        c.asc("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
            "attributes": {"duration": dur, "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                              "territory": {"data": {"type": "territories", "id": t}}}}})
    print(" trial", dur, "territories", len(PRICES))


PRICES = base_prices()
ids = {}
for v in VARIANTS:
    sid = ensure_sub(v)
    ensure_prices(sid)
    if v["trial"]:
        ensure_trial(sid, v["trial"])
    ids[v["productId"]] = sid
json.dump(ids, sys.stdout)
