#!/usr/bin/env python3
"""Translates the Kizuki clip library into the app's learner languages (vi, id, th, ko, pt).

Source: the generated library in public/data (clips, dictionary, explanation notes). Every
translation is made from the Japanese with the English text as the author's reference, then
checked twice before it can ship:
  1. deterministic checks on every item (all fields present, Japanese copied exactly, right
     script, no English left over, sane length) — failed items are re-translated with the
     problem named;
  2. an AI review pass (`review`) that reads Japanese + English + translation side by side and
     returns corrected text for anything wrong; fixes are applied only if they also pass (1).

Work is cached per item under WORK (default /tmp/kizuki-i18n) keyed by a hash of its source, so
runs resume and only changed clips are redone. `store` writes the verified result into
scripts/i18n/content/<lang>/ (the durable, committed source the packs are built from).

  python3 scripts/i18n/translate_content.py translate --lang vi --kind clips --workers 24
  python3 scripts/i18n/translate_content.py review    --lang vi --kind clips --workers 24
  python3 scripts/i18n/translate_content.py translate --lang vi --kind grammar
  python3 scripts/i18n/translate_content.py translate --lang vi --kind dict
  python3 scripts/i18n/translate_content.py status
  python3 scripts/i18n/translate_content.py store     --lang vi
Options: --only id1,id2  --limit N  --starter (starter clips first/only)  --max-credits N
"""
import argparse
import concurrent.futures as cf
import glob
import hashlib
import json
import os
import random
import re
import sys
import threading
import time

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(ROOT, "public", "data")
WORK = os.environ.get("KIZUKI_I18N_WORK", "/tmp/kizuki-i18n")
STORE = os.path.join(HERE, "content")
GATEWAY = "https://ai.gateway.lovable.dev/v1"
# Models used, with workspace credit price per token (from the gateway model listing, for the
# ledger) and API surface. OpenAI models go through /responses, Gemini through /chat/completions
# (both zero-retention surfaces). Override with --model / --review-model.
MODELS = {
    "openai/gpt-6-astra": {"api": "responses", "in": 0.00004, "cached": 0.000004, "out": 0.0002},
    "openai/gpt-6.1-sol": {"api": "responses", "in": 0.000008, "cached": 0.0000008, "out": 0.00004},
    "google/gemini-3.8-flash": {"api": "chat", "in": 0.000003, "cached": 0.0000003, "out": 0.000015},
    "google/gemini-3.1-pro-preview": {"api": "chat", "in": 0.000008, "cached": 0.0000008, "out": 0.000048},
}
CFG = {"model": "google/gemini-3.8-flash", "review_model": "openai/gpt-6.1-sol"}
LANGS = ["vi", "id", "th", "ko", "pt"]
STYLE = json.load(open(os.path.join(HERE, "style.json"), encoding="utf-8"))

JA_RUN = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uff66-\uff9f々〆〜ー・]+")
EN_STOP = re.compile(r"\b(the|is|are|of|with|this|that|used|here|means|which|when|polite|form|word|sentence|marks)\b", re.I)
QUOTED = re.compile(r"[\"“”'‘’«»「」『』][^\"“”'‘’«»「」『』]{0,40}[\"“”'‘’«»「」『』]")
SCRIPT = {"th": re.compile(r"[\u0e00-\u0e7f]"), "ko": re.compile(r"[\uac00-\ud7af]")}
VI_MARK = re.compile(r"[\u00c0-\u00ff\u0102\u0103\u0110\u0111\u0128\u0129\u0168\u0169\u01a0\u01a1\u01af\u01b0\u1ea0-\u1ef9]")

_lock = threading.Lock()
_stop = threading.Event()


# ----------------------------------------------------------------------------- source data

def load_library():
    index = json.load(open(os.path.join(DATA, "content.json"), encoding="utf-8"))
    clips = [c for p in index["parts"] for c in json.load(open(os.path.join(DATA, p), encoding="utf-8"))["clips"]]
    return index, clips


def load_notes(cid):
    f = os.path.join(DATA, "explain", f"{cid}.json")
    if not os.path.exists(f):
        return {"w": {}, "l": {}}
    j = json.load(open(f, encoding="utf-8"))
    return {"w": j.get("w", {}), "l": j.get("l", {})}


def h(obj):
    return hashlib.sha1(json.dumps(obj, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()[:16]


# ----------------------------------------------------------------------------- gateway

def ledger_path():
    return os.path.join(WORK, "ledger.jsonl")


def spent(lang=None):
    """Credits in the ledger; with `lang`, only that language's content calls."""
    total = 0.0
    if os.path.exists(ledger_path()):
        for line in open(ledger_path(), encoding="utf-8"):
            try:
                j = json.loads(line)
                if lang is None or j["tag"].startswith(f"{lang}:"):
                    total += j["credits"]
            except Exception:
                pass
    return total


def record(usage, tag, model):
    price = MODELS[model]
    inp = usage.get("input_tokens", usage.get("prompt_tokens", 0)) or 0
    det = usage.get("input_tokens_details") or usage.get("prompt_tokens_details") or {}
    cached = det.get("cached_tokens", 0) or 0
    out = usage.get("output_tokens", usage.get("completion_tokens", 0)) or 0
    odet = usage.get("output_tokens_details") or usage.get("completion_tokens_details") or {}
    reasoning = odet.get("reasoning_tokens", 0) or 0
    credits = (inp - cached) * price["in"] + cached * price["cached"] + out * price["out"]
    with _lock:
        os.makedirs(WORK, exist_ok=True)
        with open(ledger_path(), "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": int(time.time()), "tag": tag, "model": model, "in": inp, "cached": cached, "out": out, "reasoning": reasoning, "credits": round(credits, 5)}) + "\n")


class Terminal(Exception):
    pass


def _body(model, instructions, prompt, schema, name, effort):
    if MODELS[model]["api"] == "responses":
        return f"{GATEWAY}/responses", {
            "model": model, "instructions": instructions, "input": prompt,
            "reasoning": {"effort": effort}, "store": False, "stream": True,
            "text": {"format": {"type": "json_schema", "name": name, "strict": True, "schema": schema}},
        }
    return f"{GATEWAY}/chat/completions", {
        "model": model, "stream": True, "stream_options": {"include_usage": True},
        "reasoning_effort": effort,
        "messages": [{"role": "system", "content": instructions}, {"role": "user", "content": prompt}],
        "response_format": {"type": "json_schema", "json_schema": {"name": name, "strict": True, "schema": schema}},
    }


def call(instructions, prompt, schema, name, tag, effort="low", model=None):
    model = model or CFG["model"]
    url, body = _body(model, instructions, prompt, schema, name, effort)
    headers = {
        "Authorization": f"Bearer {os.environ['LOVABLE_API_KEY']}",
        "Content-Type": "application/json",
        "X-Lovable-AIG-SDK": "fetch",
        "Accept": "text/event-stream",
    }
    last = None
    for attempt in range(6):
        if _stop.is_set():
            raise Terminal("stopped")
        try:
            with requests.post(url, json=body, headers=headers, stream=True, timeout=(30, 900)) as r:
                if r.status_code in (402, 403):
                    _stop.set()
                    raise Terminal(f"HTTP {r.status_code}: {r.text[:300]}")
                if r.status_code != 200:
                    last = f"HTTP {r.status_code}: {r.text[:200]}"
                    if r.status_code in (429, 500, 502, 503, 504):
                        wait = float(r.headers.get("retry-after") or 0) or min(120, 6 * 2 ** attempt)
                        time.sleep(wait + random.random() * 3)
                        continue
                    raise Terminal(last)
                text, usage, finish = [], None, None
                for raw in r.iter_lines(decode_unicode=False):
                    if not raw:
                        continue
                    line = raw.decode("utf-8", "replace")
                    if not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if not data or data == "[DONE]":
                        continue
                    ev = json.loads(data)
                    t = ev.get("type")
                    if t == "response.output_text.delta":
                        text.append(ev["delta"])
                    elif t == "response.completed":
                        usage = (ev.get("response") or {}).get("usage")
                    elif t in ("response.failed", "error") or ev.get("error"):
                        raise RuntimeError(json.dumps(ev)[:300])
                    elif t == "response.incomplete":
                        raise RuntimeError("incomplete " + json.dumps((ev.get("response") or {}).get("incomplete_details")))
                    elif "choices" in ev:
                        for ch in ev["choices"]:
                            d = (ch.get("delta") or {}).get("content")
                            if d:
                                text.append(d)
                            if ch.get("finish_reason"):
                                finish = ch["finish_reason"]
                        if ev.get("usage"):
                            usage = ev["usage"]
                if usage:
                    record(usage, tag, model)
                if finish and finish not in ("stop", "STOP"):
                    raise RuntimeError(f"finish_reason {finish}")
                return json.loads("".join(text))
        except Terminal:
            raise
        except Exception as e:  # network / parse: retry
            last = repr(e)[:300]
            time.sleep(min(90, 5 * 2 ** attempt) + random.random() * 3)
    raise RuntimeError(last or "failed")


# ----------------------------------------------------------------------------- checks

def norm(s):
    return s.replace("～", "〜").replace("　", " ")


def ja_missing(src, out):
    """Japanese runs of the English note that the translation dropped or changed."""
    o = norm(out)
    return [run for run in JA_RUN.findall(norm(src)) if run not in o and run not in ("・", "ー")]


NAME = re.compile(r"[A-Z0-9][\w'’.&-]*(?: [A-Z0-9][\w'’.&-]*){0,3}")


def text_problem(lang, src, out, field, ja_check=True, ratio=True):
    if not isinstance(out, str):
        return f"{field}: missing"
    s, o = src.strip(), out.strip()
    if s and not o:
        return f"{field}: empty"
    if not s:
        return None
    if NAME.fullmatch(s) and s.lower() in o.lower() and len(o) <= len(s) + 40:
        return None  # a name or acronym ("Shin", "NHK", "Takaichi") may stay in Latin letters, optionally explained
    if ja_check:
        miss = ja_missing(s, o)
        if miss:
            return f"{field}: Japanese text not copied exactly ({', '.join(miss[:3])})"
    plain = QUOTED.sub("", o)
    letters = re.sub(r"[\W\d_]", "", JA_RUN.sub("", s))
    if lang in SCRIPT and len(letters) >= 3 and not SCRIPT[lang].search(o):
        return f"{field}: not written in {STYLE['langs'][lang]['name']}"
    if lang in ("vi", "id", "pt"):
        if len(EN_STOP.findall(plain)) >= 2:
            return f"{field}: English words left in the translation"
        if len(letters) >= 12 and o.lower() == s.lower():
            return f"{field}: left untranslated"
    else:
        if len(EN_STOP.findall(plain)) >= 1:
            return f"{field}: English words left in the translation"
    if lang == "vi" and len(letters) >= 20 and not VI_MARK.search(o):
        return f"{field}: Vietnamese without diacritics"
    r = len(o) / max(1, len(s))
    lo = 0.25 if lang in ("th", "ko") else 0.45
    if ratio and len(s) >= 25 and (r < lo or r > 3.2):
        return f"{field}: length looks wrong ({len(o)} vs {len(s)} characters)"
    return None


# ----------------------------------------------------------------------------- clips

CLIP_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["title", "lines"],
    "properties": {
        "title": {"type": "string"},
        "lines": {"type": "array", "items": {
            "type": "object", "additionalProperties": False, "required": ["i", "tr", "lit", "tip", "words"],
            "properties": {
                "i": {"type": "integer"}, "tr": {"type": "string"}, "lit": {"type": "string"}, "tip": {"type": "string"},
                "words": {"type": "array", "items": {
                    "type": "object", "additionalProperties": False, "required": ["k", "m", "n"],
                    "properties": {"k": {"type": "string"}, "m": {"type": "string"}, "n": {"type": "string"}}}},
            }}},
    },
}


def lang_rules(lang):
    L = STYLE["langs"][lang]
    return (STYLE["common"].replace("{name}", L["name"]) + f"\n\nAudience: {L['audience']}\nVoice: {L['voice']}\n\nTerminology glossary (English = {L['name']}):\n{L['glossary']}")


def clip_instructions(lang):
    name = STYLE["langs"][lang]["name"]
    return lang_rules(lang) + f"""

TASK: localize one clip into {name}. For every LINE return:
- i: the line number.
- tr: the {name} subtitle for the Japanese line `ja` — natural spoken {name}, the speaker's tone and politeness, as a professional subtitler would write it. Keep it about as short as the English.
- lit: a literal {name} rendering of `ja` that follows the Japanese structure, like the English `lit` does ("" when the line has no lit).
- tip: the {name} translation of the English `tip` ("" when none).
- words: for EVERY word key [k] listed under the line, k plus:
  - m: what the word means IN THIS SENTENCE, 1-6 {name} words, no romaji, no quotes (same style as the English m: lowercase common words, short).
  - n: the {name} translation of the English note n — one clear sentence, same facts, Japanese copied exactly.
Also return title: the {name} version of the English clip title (short, natural, sentence style for {name}).
Return lines in order with exactly the given line numbers and word keys. Never skip a key."""


def clip_payload(c, notes, video_title):
    rows = [f"CLIP TITLE (English): {c['title']}", f"YouTube video title (Japanese, context only): {video_title}", f"Level: {c['level']}"]
    for li, l in enumerate(c["lines"]):
        ln = notes["l"].get(str(li))
        rows.append(f"\nLINE {li}" + (f" (speaker: {l['sp']})" if l.get("sp") else ""))
        rows.append(f"ja: {l['ja']}")
        rows.append(f"en: {l['en']}")
        if ln:
            rows.append(f"lit: {ln['lit']}")
            rows.append(f"tip: {ln['tip']}")
        for wi, w in enumerate(l["words"]):
            k = f"{li}.{wi}"
            wn = notes["w"].get(k)
            if not wn:
                continue
            head = w["s"] + (f" (dictionary form {w['b']})" if w.get("b") and w["b"] != w["s"] else "")
            rows.append(f"  [{k}] {head} | m: {wn['m']} | n: {wn['n']}")
    return "\n".join(rows)


def clip_source(c, notes):
    return {"title": c["title"], "lines": [l["en"] for l in c["lines"]], "ja": [l["ja"] for l in c["lines"]], "w": notes["w"], "l": notes["l"]}


def clip_problems(lang, c, notes, out):
    p = []
    if not isinstance(out, dict):
        return ["no result"]
    e = text_problem(lang, c["title"], out.get("title"), "title", ja_check=False)
    if e:
        p.append(e)
    lines = {l.get("i"): l for l in out.get("lines", []) if isinstance(l, dict)}
    for li, l in enumerate(c["lines"]):
        o = lines.get(li)
        if not o:
            p.append(f"line {li}: missing")
            continue
        e = text_problem(lang, l["en"], o.get("tr"), f"line {li} tr", ja_check=False)
        if e:
            p.append(e)
        ln = notes["l"].get(str(li))
        if ln:
            for f in ("lit", "tip"):
                e = text_problem(lang, ln[f], o.get(f), f"line {li} {f}", ja_check=(f == "tip"))
                if e:
                    p.append(e)
        words = {w.get("k"): w for w in o.get("words", []) if isinstance(w, dict)}
        for k, wn in notes["w"].items():
            if not k.startswith(f"{li}."):
                continue
            ow = words.get(k)
            if not ow:
                p.append(f"word {k}: missing")
                continue
            e = text_problem(lang, wn["m"], ow.get("m"), f"word {k} m", ja_check=False, ratio=False) or text_problem(lang, wn["n"], ow.get("n"), f"word {k} n")
            if e:
                p.append(e)
    return p


def clip_result(c, notes, out):
    """Compact overlay form: {t, l: [tr per line], w: {k: {m, n}}, n: {line: {lit, tip}}}."""
    lines = {l["i"]: l for l in out["lines"]}
    res = {"t": out["title"].strip(), "l": [], "w": {}, "n": {}}
    for li, _ in enumerate(c["lines"]):
        o = lines[li]
        res["l"].append(o["tr"].strip())
        if str(li) in notes["l"]:
            res["n"][str(li)] = {"lit": o["lit"].strip(), "tip": o["tip"].strip()}
        for w in o["words"]:
            if w["k"] in notes["w"] and w["k"].startswith(f"{li}."):
                res["w"][w["k"]] = {"m": w["m"].strip(), "n": w["n"].strip()}
    return res


def result_as_out(res):
    """Back to the model's shape (for review prompts)."""
    lines = []
    for li, tr in enumerate(res["l"]):
        n = res["n"].get(str(li), {"lit": "", "tip": ""})
        lines.append({"i": li, "tr": tr, "lit": n["lit"], "tip": n["tip"],
                      "words": [{"k": k, "m": v["m"], "n": v["n"]} for k, v in res["w"].items() if k.startswith(f"{li}.")]})
    return {"title": res["t"], "lines": lines}


def clip_file(lang, cid):
    return os.path.join(WORK, lang, "clips", f"{cid}.json")


def translate_clip(lang, c, notes, video_title):
    f = clip_file(lang, c["id"])
    src = h(clip_source(c, notes))
    if os.path.exists(f):
        old = json.load(open(f, encoding="utf-8"))
        if old.get("src") == src:
            return "cached"
    prompt = clip_payload(c, notes, video_title)
    instr = clip_instructions(lang)
    problems = []
    for attempt in range(4):
        extra = ""
        if problems:
            extra = "\n\nYOUR PREVIOUS ANSWER HAD THESE PROBLEMS — fix them all:\n- " + "\n- ".join(problems[:15])
        out = call(instr, prompt + extra, CLIP_SCHEMA, "clip_localization", f"{lang}:clip")
        problems = clip_problems(lang, c, notes, out)
        if not problems:
            res = clip_result(c, notes, out)
            write_json(f, {"src": src, "res": res, "review": None})
            return f"ok (try {attempt + 1})"
    write_json(f + ".failed", {"src": src, "problems": problems, "out": out})
    return "FAILED " + "; ".join(problems[:3])


# ----------------------------------------------------------------------------- review

REVIEW_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["issues"],
    "properties": {"issues": {"type": "array", "items": {
        "type": "object", "additionalProperties": False, "required": ["field", "severity", "problem", "fix"],
        "properties": {
            "field": {"type": "string"},
            "severity": {"type": "string", "enum": ["critical", "major", "minor"]},
            "problem": {"type": "string"},
            "fix": {"type": "string"},
        }}}},
}


def review_instructions(lang):
    name = STYLE["langs"][lang]["name"]
    return lang_rules(lang) + f"""

TASK: you are the second, independent reviewer (a native {name} Japanese teacher and editor). Compare each {name} field against the Japanese and the English reference. Report ONLY real problems:
- critical: wrong meaning, mistranslation of the Japanese, wrong grammar explanation, Japanese text altered/removed, wrong language, missing content.
- major: unnatural or machine-like {name}, wrong register/pronouns for the speakers, inconsistent glossary terms, awkward word that a native would not use, a word meaning (m) that does not fit the sentence.
- minor: small style improvements that clearly make it better.
For each issue give field exactly as labelled (e.g. "title", "line 3 tr", "line 3 lit", "line 3 tip", "word 3.2 m", "word 3.2 n"), the problem in one short English sentence, and fix = the complete corrected {name} text for that field. If everything is correct and natural, return an empty list. Do not report matters of taste."""


def review_payload(c, notes, res, video_title):
    rows = [f"YouTube video title (context only): {video_title}", f"title | en: {c['title']} | {res['t']}"]
    for li, l in enumerate(c["lines"]):
        rows.append(f"\nLINE {li}" + (f" (speaker: {l['sp']})" if l.get("sp") else ""))
        rows.append(f"ja: {l['ja']}")
        rows.append(f"line {li} tr | en: {l['en']} | {res['l'][li]}")
        ln = notes["l"].get(str(li))
        if ln:
            rn = res["n"].get(str(li), {"lit": "", "tip": ""})
            rows.append(f"line {li} lit | en: {ln['lit']} | {rn['lit']}")
            rows.append(f"line {li} tip | en: {ln['tip']} | {rn['tip']}")
        for wi, w in enumerate(l["words"]):
            k = f"{li}.{wi}"
            if k not in notes["w"]:
                continue
            rw = res["w"].get(k, {"m": "", "n": ""})
            rows.append(f"  word {k} ({w['s']}) m | en: {notes['w'][k]['m']} | {rw['m']}")
            rows.append(f"  word {k} n | en: {notes['w'][k]['n']} | {rw['n']}")
    return "\n".join(rows)


FIELD = re.compile(r"^\s*(title|line (\d+) (tr|lit|tip)|word (\d+\.\d+) (m|n))\s*$")


def apply_fix(lang, c, notes, res, field, fix):
    m = FIELD.match(field)
    if not m:
        return False
    fix = fix.strip()
    if m.group(1) == "title":
        if text_problem(lang, c["title"], fix, "title", ja_check=False):
            return False
        res["t"] = fix
        return True
    if m.group(2) is not None:
        li, f = int(m.group(2)), m.group(3)
        if li >= len(c["lines"]):
            return False
        if f == "tr":
            if text_problem(lang, c["lines"][li]["en"], fix, "tr", ja_check=False):
                return False
            res["l"][li] = fix
            return True
        ln = notes["l"].get(str(li))
        if not ln or text_problem(lang, ln[f], fix, f, ja_check=(f == "tip")):
            return False
        res["n"].setdefault(str(li), {"lit": "", "tip": ""})[f] = fix
        return True
    k, f = m.group(4), m.group(5)
    if k not in notes["w"] or text_problem(lang, notes["w"][k][f], fix, f, ja_check=(f == "n"), ratio=(f == "n")):
        return False
    res["w"][k][f] = fix
    return True


def review_clip(lang, c, notes, video_title):
    f = clip_file(lang, c["id"])
    if not os.path.exists(f):
        return "not translated"
    rec = json.load(open(f, encoding="utf-8"))
    if rec.get("src") != h(clip_source(c, notes)):
        return "stale"
    if rec.get("review") is not None:
        return "cached"
    res = rec["res"]
    out = call(review_instructions(lang), review_payload(c, notes, res, video_title), REVIEW_SCHEMA, "review", f"{lang}:review", model=CFG["review_model"])
    applied, rejected = [], []
    for it in out["issues"]:
        (applied if apply_fix(lang, c, notes, res, it["field"], it["fix"]) else rejected).append(it)
    rec["res"] = res
    rec["review"] = {"applied": applied, "rejected": rejected, "at": int(time.time())}
    write_json(f, rec)
    sev = {}
    for it in applied:
        sev[it["severity"]] = sev.get(it["severity"], 0) + 1
    return f"reviewed: {len(applied)} fixed {sev or ''} {len(rejected)} rejected"


# ----------------------------------------------------------------------------- grammar + dict

GRAMMAR_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["items"],
    "properties": {"items": {"type": "array", "items": {
        "type": "object", "additionalProperties": False, "required": ["id", "text"],
        "properties": {"id": {"type": "integer"}, "text": {"type": "string"}}}}},
}

DICT_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["entries"],
    "properties": {"entries": {"type": "array", "items": {
        "type": "object", "additionalProperties": False, "required": ["id", "senses", "examples"],
        "properties": {
            "id": {"type": "string"},
            "senses": {"type": "array", "items": {"type": "string"}},
            "examples": {"type": "array", "items": {"type": "string"}},
        }}}},
}


def grammar_items():
    _, clips = load_library()
    seen = {}
    for c in clips:
        for g in c["grammar"]:
            seen.setdefault(g, None)
    return sorted(seen)


def split_grammar(g):
    if "—" in g:
        a, b = g.split("—", 1)
        return a.strip(), b.strip()
    return g.strip(), ""


def jsonl_cache(lang, kind):
    f = os.path.join(WORK, lang, f"{kind}.jsonl")
    out = {}
    if os.path.exists(f):
        for line in open(f, encoding="utf-8"):
            try:
                j = json.loads(line)
                out[j["key"]] = j["val"]
            except Exception:
                pass
    return f, out


def append_jsonl(f, rows):
    with _lock:
        os.makedirs(os.path.dirname(f), exist_ok=True)
        with open(f, "a", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")


def translate_grammar_batch(lang, batch, f):
    name = STYLE["langs"][lang]["name"]
    instr = lang_rules(lang) + f"""

TASK: each item is a Japanese grammar pattern with a short English description. Return for every id the {name} description only (not the pattern): short like the English (a few words), using the glossary terms, natural for a {name} learner. Keep any Japanese in the description exactly."""
    prompt = "\n".join(f"{i}. pattern: {p} | English: {d}" for i, (p, d) in enumerate(batch))
    problems = []
    for attempt in range(3):
        out = call(instr, prompt + ("\n\nFix these problems from your previous answer:\n- " + "\n- ".join(problems) if problems else ""), GRAMMAR_SCHEMA, "grammar", f"{lang}:grammar")
        got = {it["id"]: it["text"].strip() for it in out["items"]}
        problems, rows = [], []
        for i, (p, d) in enumerate(batch):
            e = text_problem(lang, d, got.get(i), f"item {i}")
            if e:
                problems.append(e)
            else:
                rows.append({"key": h([p, d]), "val": got[i]})
        if rows:
            append_jsonl(f, rows)
        if not problems:
            return f"ok {len(rows)}"
        batch_left = [b for i, b in enumerate(batch) if text_problem(lang, b[1], got.get(i), "x")]
        batch, prompt = batch_left, "\n".join(f"{i}. pattern: {p} | English: {d}" for i, (p, d) in enumerate(batch_left))
    return f"partial: {len(problems)} left"


def dict_entries():
    return json.load(open(os.path.join(DATA, "dict.json"), encoding="utf-8"))


def translate_dict_batch(lang, batch, f):
    name = STYLE["langs"][lang]["name"]
    instr = lang_rules(lang) + f"""

TASK: localize Japanese dictionary entries for a learner dictionary. For every entry id return:
- senses: one {name} gloss per English sense, same order and count. Each English sense is a list of synonyms separated by "; " — write the {name} gloss the same way: the most common, natural {name} equivalent FIRST, then 1-3 more synonyms if they add meaning, separated by "; ". Keep explanatory parentheses like "(refuse)" translated. Dictionary style: short, no full sentences, lowercase where natural.
- examples: the {name} translation of each example sentence, made from the Japanese (English given as reference), same order and count.
Use the part of speech to choose the right word class (a verb gloss must be a verb, etc.)."""
    rows_in = []
    for eid, e in batch:
        senses = " || ".join(f"[{', '.join(m['pos'])}] {m['g']}" for m in e["m"])
        ex = " || ".join(f"{x['ja']} = {x['en']}" for x in e["ex"])
        rows_in.append(f"id {eid}: {e['w']} ({e['r']}) senses: {senses}" + (f"\n   examples: {ex}" if ex else ""))
    prompt = "\n".join(rows_in)
    out = call(instr, prompt, DICT_SCHEMA, "dictionary", f"{lang}:dict")
    got = {it["id"]: it for it in out["entries"]}
    rows, bad = [], []
    for eid, e in batch:
        o = got.get(eid)
        ok = o is not None and len(o["senses"]) == len(e["m"]) and len(o["examples"]) == len(e["ex"])
        if ok:
            for i, m in enumerate(e["m"]):
                if text_problem(lang, m["g"], o["senses"][i], "sense", ja_check=False, ratio=False):
                    ok = False
            for i, x in enumerate(e["ex"]):
                if text_problem(lang, x["en"], o["examples"][i], "example", ja_check=False):
                    ok = False
        if ok:
            rows.append({"key": eid, "val": {"src": h([e["m"], e["ex"]]), "m": [s.strip() for s in o["senses"]], "ex": [s.strip() for s in o["examples"]]}})
        else:
            bad.append((eid, e))
    if rows:
        append_jsonl(f, rows)
    return rows, bad


DICT_REVIEW_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["fixes"],
    "properties": {"fixes": {"type": "array", "items": {
        "type": "object", "additionalProperties": False, "required": ["id", "senses", "examples", "problem"],
        "properties": {
            "id": {"type": "string"},
            "senses": {"type": "array", "items": {"type": "string"}},
            "examples": {"type": "array", "items": {"type": "string"}},
            "problem": {"type": "string"},
        }}}},
}


def review_dict_batch(lang, batch, f):
    """Second check of dictionary entries: a different model compares each gloss/example with the
    Japanese and English and returns complete corrected lists only for real problems."""
    name = STYLE["langs"][lang]["name"]
    instr = lang_rules(lang) + f"""

TASK: you are the second, independent reviewer of a {name} learner dictionary. For each entry compare every {name} sense with its English sense and the part of speech, and every {name} example with its Japanese sentence. Report an entry ONLY when something is really wrong: a wrong or misleading meaning, the wrong word class, an unnatural word a native {name} speaker would not use, an example translation that does not match the Japanese, or English left in the text. For a reported entry return the COMPLETE corrected lists: `senses` (same count and order as the English senses, "; " between synonyms) and `examples` (same count and order). problem = one short English sentence. Return an empty list when all entries are good."""
    rows_in = []
    for eid, e, v in batch:
        senses = " || ".join(f"[{', '.join(m['pos'])}] en: {m['g']} => {name}: {v['m'][i]}" for i, m in enumerate(e["m"]))
        ex = " || ".join(f"{x['ja']} (en: {x['en']}) => {v['ex'][i]}" for i, x in enumerate(e["ex"]))
        rows_in.append(f"id {eid}: {e['w']} ({e['r']})\n   senses: {senses}" + (f"\n   examples: {ex}" if ex else ""))
    out = call(instr, "\n".join(rows_in), DICT_REVIEW_SCHEMA, "dictionary_review", f"{lang}:dict-review", model=CFG["review_model"])
    fixes = {x["id"]: x for x in out["fixes"]}
    rows, fixed, rejected = [], 0, 0
    for eid, e, v in batch:
        new = dict(v, reviewed=True)
        fx = fixes.get(eid)
        if fx:
            ok = len(fx["senses"]) == len(e["m"]) and len(fx["examples"]) == len(e["ex"])
            ok = ok and not any(text_problem(lang, m["g"], fx["senses"][i], "sense", ja_check=False, ratio=False) for i, m in enumerate(e["m"]))
            ok = ok and not any(text_problem(lang, x["en"], fx["examples"][i], "example", ja_check=False) for i, x in enumerate(e["ex"]))
            if ok:
                new.update(m=[x.strip() for x in fx["senses"]], ex=[x.strip() for x in fx["examples"]], fix=fx["problem"])
                fixed += 1
            else:
                rejected += 1
        rows.append({"key": eid, "val": new})
    append_jsonl(f, rows)
    return f"reviewed {len(rows)}: {fixed} fixed, {rejected} rejected"


GRAMMAR_REVIEW_SCHEMA = {
    "type": "object", "additionalProperties": False, "required": ["fixes"],
    "properties": {"fixes": {"type": "array", "items": {
        "type": "object", "additionalProperties": False, "required": ["id", "text", "problem"],
        "properties": {"id": {"type": "integer"}, "text": {"type": "string"}, "problem": {"type": "string"}}}}},
}


def review_grammar_batch(lang, batch, f):
    name = STYLE["langs"][lang]["name"]
    instr = lang_rules(lang) + f"""

TASK: second, independent review of short {name} descriptions of Japanese grammar patterns. Report an item ONLY when its {name} description is wrong, misleading, uses a non-standard grammar term (see the glossary) or sounds unnatural; give the complete corrected description (short, like the English). Return an empty list when all are good."""
    prompt = "\n".join(f"{i}. pattern: {p} | English: {d} | {name}: {t}" for i, (p, d, t) in enumerate(batch))
    out = call(instr, prompt, GRAMMAR_REVIEW_SCHEMA, "grammar_review", f"{lang}:grammar-review", model=CFG["review_model"])
    fixes = {x["id"]: x for x in out["fixes"]}
    rows, fixed = [], 0
    for i, (p, d, t) in enumerate(batch):
        fx = fixes.get(i)
        val = t
        if fx and not text_problem(lang, d, fx["text"], f"item {i}"):
            val, fixed = fx["text"].strip(), fixed + 1
        rows.append({"key": h([p, d]), "val": val, "reviewed": True})
    append_jsonl(f, rows)
    return f"reviewed {len(rows)}: {fixed} fixed"


def grammar_reviewed(lang):
    f = os.path.join(WORK, lang, "grammar.jsonl")
    done = set()
    if os.path.exists(f):
        for line in open(f, encoding="utf-8"):
            try:
                j = json.loads(line)
                if j.get("reviewed"):
                    done.add(j["key"])
            except Exception:
                pass
    return done


# ----------------------------------------------------------------------------- utilities

def write_json(f, obj):
    os.makedirs(os.path.dirname(f), exist_ok=True)
    tmp = f + f".tmp{threading.get_ident()}"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False)
    os.replace(tmp, f)


def select_clips(a, index, clips):
    # Most-seen first: the curated starter clips in their order, then by quality — so a budget
    # stop leaves the least-watched clips in English, never the first ones a learner sees.
    order = {cid: i for i, cid in enumerate(index.get("starter", []))}
    clips = sorted(clips, key=lambda c: (order.get(c["id"], len(order)), -c.get("quality", 0), c["id"]))
    if a.only:
        want = set(a.only.split(","))
        clips = [c for c in clips if c["id"] in want]
    if a.starter:
        order = {cid: i for i, cid in enumerate(index.get("starter", []))}
        clips = sorted([c for c in clips if c["id"] in order], key=lambda c: order[c["id"]])
    if a.limit:
        clips = clips[: a.limit]
    return clips


def run_pool(fn, items, workers, label, max_credits, lang=None, lang_credits=0):
    done = 0
    t0 = time.time()
    with cf.ThreadPoolExecutor(workers) as ex:
        futs = {}
        it = iter(items)

        def submit_next():
            if max_credits and spent() >= max_credits:
                _stop.set()
                return False
            if lang_credits and spent(lang) >= lang_credits:
                print(f"[{label}] language budget {lang_credits} reached", flush=True)
                _stop.set()
                return False
            try:
                x = next(it)
            except StopIteration:
                return False
            futs[ex.submit(fn, x)] = x
            return True

        for _ in range(workers):
            if not submit_next():
                break
        while futs:
            finished, _ = cf.wait(list(futs), return_when=cf.FIRST_COMPLETED)
            for fu in finished:
                x = futs.pop(fu)
                try:
                    msg = fu.result()
                except Terminal as e:
                    msg = f"STOP {e}"
                except Exception as e:
                    msg = f"ERROR {repr(e)[:200]}"
                done += 1
                key = x["id"] if isinstance(x, dict) and "id" in x else (x[0] if isinstance(x, tuple) else str(x)[:30])
                print(f"[{label}] {done}/{len(items)} {key} {msg}  ({time.time() - t0:.0f}s, {spent():.1f} credits total)", flush=True)
                if not _stop.is_set():
                    submit_next()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["translate", "review", "status", "store"])
    ap.add_argument("--lang", default=",".join(LANGS))
    ap.add_argument("--kind", default="clips", choices=["clips", "grammar", "dict"])
    ap.add_argument("--workers", type=int, default=12)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--only")
    ap.add_argument("--starter", action="store_true")
    ap.add_argument("--max-credits", type=float, default=0)
    ap.add_argument("--lang-credits", type=float, default=0, help="stop when this language's content calls reach N credits")
    ap.add_argument("--model", default=CFG["model"], choices=sorted(MODELS))
    ap.add_argument("--review-model", default=CFG["review_model"], choices=sorted(MODELS))
    a = ap.parse_args()
    CFG["model"], CFG["review_model"] = a.model, a.review_model
    langs = [l for l in a.lang.split(",") if l]
    for l in langs:
        if l not in LANGS:
            sys.exit(f"unknown language {l}")
    index, clips = load_library()

    if a.cmd == "status":
        print(f"credits spent (ledger): {spent():.1f}")
        for l in langs:
            files = glob.glob(os.path.join(WORK, l, "clips", "*.json"))
            reviewed = sum(1 for f in files if json.load(open(f, encoding="utf-8")).get("review") is not None)
            failed = len(glob.glob(os.path.join(WORK, l, "clips", "*.failed")))
            g = len(jsonl_cache(l, "grammar")[1]); d = len(jsonl_cache(l, "dict")[1])
            print(f"{l}: clips {len(files)}/{len(clips)} reviewed {reviewed} failed {failed} | grammar {g} | dict {d}")
        return

    if a.cmd == "store":
        import store_content  # noqa: local module
        for l in langs:
            store_content.store(l)
        return

    for lang in langs:
        if a.kind == "clips":
            sel = select_clips(a, index, clips)
            fn = translate_clip if a.cmd == "translate" else review_clip
            run_pool(lambda c: fn(lang, c, load_notes(c["id"]), index["videos"].get(c["videoId"], {}).get("title", "")), sel, a.workers, f"{lang} {a.cmd}", a.max_credits, lang, a.lang_credits)
        elif a.kind == "grammar" and a.cmd == "review":
            f, cache = jsonl_cache(lang, "grammar")
            done = grammar_reviewed(lang)
            todo = [(p, d, cache[h([p, d])]) for p, d in (split_grammar(g) for g in grammar_items()) if d and h([p, d]) in cache and h([p, d]) not in done]
            batches = [todo[i:i + 60] for i in range(0, len(todo), 60)]
            run_pool(lambda b: review_grammar_batch(lang, b, f), batches, a.workers, f"{lang} grammar review", a.max_credits, lang, a.lang_credits)
        elif a.kind == "dict" and a.cmd == "review":
            f, cache = jsonl_cache(lang, "dict")
            d = dict_entries()
            todo = [(k, d[k], v) for k, v in sorted(cache.items()) if k in d and v.get("src") == h([d[k]["m"], d[k]["ex"]]) and not v.get("reviewed")]
            if a.limit:
                todo = todo[: a.limit]
            batches = [todo[i:i + 40] for i in range(0, len(todo), 40)]
            run_pool(lambda b: review_dict_batch(lang, b, f), batches, a.workers, f"{lang} dict review", a.max_credits, lang, a.lang_credits)
        elif a.kind == "grammar":
            f, cache = jsonl_cache(lang, "grammar")
            todo = [split_grammar(g) for g in grammar_items()]
            todo = [x for x in todo if x[1] and h([x[0], x[1]]) not in cache]
            batches = [todo[i:i + 40] for i in range(0, len(todo), 40)]
            run_pool(lambda b: translate_grammar_batch(lang, b, f), batches, a.workers, f"{lang} grammar", a.max_credits, lang, a.lang_credits)
        else:
            f, cache = jsonl_cache(lang, "dict")
            d = dict_entries()
            todo = [(k, v) for k, v in sorted(d.items()) if not (k in cache and cache[k].get("src") == h([v["m"], v["ex"]]))]
            if a.limit:
                todo = todo[: a.limit]
            batches = [todo[i:i + 30] for i in range(0, len(todo), 30)]

            def work(b):
                rows, bad = translate_dict_batch(lang, b, f)
                for _ in range(2):
                    if not bad:
                        break
                    rows2, bad = translate_dict_batch(lang, bad, f)
                    rows += rows2
                return f"ok {len(rows)}" + (f", {len(bad)} failed: {[x[0] for x in bad][:5]}" if bad else "")
            run_pool(work, batches, a.workers, f"{lang} dict", a.max_credits, lang, a.lang_credits)


if __name__ == "__main__":
    main()
