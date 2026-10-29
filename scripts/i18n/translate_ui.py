#!/usr/bin/env python3
"""Translates Kizuki's interface text (scripts/i18n/ui/keys.json) into the learner languages.

Every string goes through:
  1. translation by the primary model with the screen it appears on and any context note;
  2. deterministic checks (placeholders, [highlight] and **bold** markers, line breaks,
     Japanese and emoji copied exactly, right script, nothing left in English, sane length) —
     failures are re-translated with the problem named;
  3. an independent review by a model from another vendor that sees the whole term sheet for
     consistency and returns corrections; a correction is applied only if it also passes (2);
  4. a final native-quality proofread by a third vendor's model (same acceptance rule).
Human corrections go in scripts/i18n/ui/overrides.json ({lang: {english: text}}) and win.
`store` writes the reviewed table to scripts/i18n/ui/<lang>.json, then
`bun scripts/i18n/gen_strings.ts build` turns all tables into the app catalogs.

  python3 scripts/i18n/translate_ui.py translate --lang vi
  python3 scripts/i18n/translate_ui.py review    --lang vi
  python3 scripts/i18n/translate_ui.py proof     --lang vi
  python3 scripts/i18n/translate_ui.py store     --lang vi
  python3 scripts/i18n/translate_ui.py all       # every language, all three steps
  python3 scripts/i18n/translate_ui.py status
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import sys
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import translate_content as tc  # noqa: E402  (shared gateway client, ledger and checks)

UI = os.path.join(HERE, "ui")
WORK = os.path.join(tc.WORK, "ui")
LANGS = tc.LANGS
TRANSLATE_MODEL = "openai/gpt-6-astra"
REVIEW_MODEL = "google/gemini-3.1-pro-preview"
PROOF_MODEL = "anthropic/claude-opus-5-5"  # third vendor: final native-quality proofread
PROOF_PRICE = {"in": 0.000016, "cached": 0.0000016, "out": 0.00008}

UI_VOICE = {
    "vi": "Vietnamese app UI as in top Vietnamese consumer apps: short, natural, friendly; address the user as \"bạn\" only when a pronoun is needed. Buttons are short verbs (\"Tiếp tục\", \"Lưu từ\").",
    "id": "Indonesian app UI as in top Indonesian consumer apps: casual-friendly, address the user as \"kamu\". Buttons short (\"Lanjut\", \"Simpan kata\"). Standard spelling, no slang.",
    "th": "Thai app UI as in top Thai consumer apps: short, natural, friendly; no ครับ/ค่ะ/คะ particles anywhere. Buttons short (\"ดำเนินการต่อ\" / \"ต่อไป\").",
    "ko": "Korean app UI as in top Korean consumer apps: buttons and labels in short noun/verb-stem forms (\"계속하기\", \"단어 저장\"), sentences and messages in friendly polite 해요체.",
    "pt": "Brazilian Portuguese app UI as in top Brazilian consumer apps: friendly, address the user as \"você\", buttons short (\"Continuar\", \"Salvar palavra\"). Never European Portuguese.",
}

SCREENS = {
    "welcome": "first screen of the app", "onboarding": "first-run questionnaire about the learner's goals", "trial": "paywall / free-trial offer",
    "founder": "founder story video before the paywall", "plan": "personal study plan summary", "building": "plan is being built (loading) with testimonials",
    "feed": "video feed", "clip": "video clip screen with subtitles", "ClipView": "video clip in the feed", "clip_view": "video clip in the feed",
    "WordCard": "word card that opens when a subtitle word is tapped", "word_card": "word card that opens when a subtitle word is tapped",
    "ClipSheets": "clip menus (subtitle display, speed, line options)", "clip_sheets": "clip menus (subtitle display, speed, line options)",
    "vocab": "saved words and flashcard reviews", "review": "flashcard review session", "WordLevel": "word level picker", "word_level": "word level picker",
    "settings": "settings", "support": "help & support", "account": "sign-in / account", "profile": "learner profile and stats",
    "achievements": "achievements / badges", "widgets": "home-screen widget setup", "home_widgets": "home-screen widget setup",
    "AskSheet": "Ask Kizuki AI tutor chat", "ask_sheet": "Ask Kizuki AI tutor chat", "ask": "Ask Kizuki AI tutor chat",
    "tour": "welcome tour tooltips", "WelcomeTour": "welcome tour tooltips", "paywall": "paywall / free-trial offer",
    "language": "app language picker", "explore": "browse clips by topic", "topics": "video topic names", "logic": "learning schedule wording",
    "dict.json": "dictionary part-of-speech labels", "achievements.ts": "achievements / badges", "AppFrame": "app shell / splash", "splash": "splash screen",
    "TabBar": "bottom tab bar", "tab_bar": "bottom tab bar", "saved": "saved clips", "history": "watch history", "lists": "word lists",
}
MONTHS = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
# Words that legitimately stay in Latin script / English in every language.
KEEP = re.compile(r"\b(Anime|Manga|Vlogs?|Romance|Widgets?|clips?|Feed|Drama|Kizuki|Premium|JLPT|N[1-5]|YouTube|Google|Apple|App Store|Play Store|Google Play|iPhone|Android|TikTok|Instagram|Reddit|Facebook|PostHog|RevenueCat|Aa|OK|AI|Wi-?Fi|PM|AM|Hiragana|Katakana|Romaji|Kanji|Furigana|Duolingo|Genki|email|e-mail)\b", re.I)
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B50\u2B06\u2194-\u21AA\u2705\u274C\u2728\U0001F1E6-\U0001F1FF]")
PH = re.compile(r"\{\w+\}")
_lock = threading.Lock()


def keys():
    return json.load(open(os.path.join(UI, "keys.json"), encoding="utf-8"))


def note_for(k):
    n = k.get("note") or ""
    if not n and k["key"] in MONTHS:
        n = "Abbreviated month name, used in '{month} {year}'."
    return n


def where(k):
    out = []
    for f in k["files"]:
        base = os.path.basename(f)
        stem = base.split(".")[0]
        d = SCREENS.get(base) or SCREENS.get(stem)
        if d and d not in out:
            out.append(d)
    return "; ".join(out[:3]) or "app interface"


def cache_path(lang, step):
    os.makedirs(WORK, exist_ok=True)
    return os.path.join(WORK, f"{lang}.{step}.json")


def load(lang, step):
    p = cache_path(lang, step)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


def save(lang, step, table):
    with _lock:
        p = cache_path(lang, step)
        tmp = p + ".tmp"
        json.dump(table, open(tmp, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        os.replace(tmp, p)


# ----------------------------------------------------------------------------- checks

def brand_only(en):
    return not re.search(r"[A-Za-z]{2,}", KEEP.sub("", PH.sub("", en)))


def problems(lang, en, out, note=""):
    p = []
    if not isinstance(out, str) or not out.strip():
        return ["empty"]
    if sorted(PH.findall(en)) != sorted(PH.findall(out)):
        p.append(f"placeholders must be exactly {sorted(PH.findall(en))}, got {sorted(PH.findall(out))}")
    for mark in ("[", "]", "**"):
        if en.count(mark) != out.count(mark):
            p.append(f"'{mark}' must appear {en.count(mark)} time(s), got {out.count(mark)}")
    if en.count("\n") != out.count("\n"):
        p.append(f"must keep {en.count(chr(10))} line break(s)")
    for run in tc.JA_RUN.findall(tc.norm(en)):
        if run not in tc.norm(out) and run not in ("・", "ー"):
            p.append(f"Japanese '{run}' must be copied exactly")
    if sorted(EMOJI.findall(en)) != sorted(EMOJI.findall(out)):
        p.append("emoji must be kept exactly")
    if not brand_only(en):
        if out.strip() == en.strip() and len(en) > 3:
            p.append("left in English")
        script = tc.SCRIPT.get(lang)
        if script and not script.search(out):
            p.append(f"must be written in {tc.STYLE['langs'][lang]['name']} script")
        if lang == "vi" and len(re.findall(r"[A-Za-z]{3,}", KEEP.sub("", out))) >= 2 and not tc.VI_MARK.search(out):
            p.append("Vietnamese needs its diacritics")
        left = [w for w in tc.EN_STOP.findall(KEEP.sub("", PH.sub("", out)))]
        if lang in ("th", "ko", "vi") and left:
            p.append(f"English words left: {left[:4]}")
        if lang in ("id", "pt") and len(left) >= 2:
            p.append(f"English words left: {left[:4]}")
    if "Max ~10 characters" in note and len(out) > 14:
        p.append("tab label too long: max ~10 characters")
    if len(out) > max(3 * len(en), len(en) + 40):
        p.append("much longer than the English; shorten")
    return p


# ----------------------------------------------------------------------------- prompts

def system(lang):
    L = tc.STYLE["langs"][lang]
    return f"""You are a senior native {L['name']} app localizer who also teaches Japanese. You localize Kizuki, a mobile app where people learn Japanese from real short YouTube clips (tap subtitle words, save words, review flashcards, ask an AI fox tutor named Kizuki).
Audience: {L['audience']}
Voice: {UI_VOICE[lang]}

Rules:
1. Write what a native {L['name']} UI writer would ship in a top app: natural, idiomatic, short. Never word-for-word, never machine-like. Keep the same meaning, tone and level of enthusiasm.
2. Keep every {{placeholder}} exactly as written (same names, same braces); move it wherever the grammar needs it. Values are filled in later (numbers, words, dates, prices).
3. [square brackets] mark text drawn highlighted in orange: keep the same number of [ ] pairs around the matching words. **double asterisks** mark bold: keep them around the matching words. Keep line breaks (\\n) and emoji exactly.
4. Copy Japanese (kana/kanji) exactly. Keep brand and product names: Kizuki, Kizuki Premium, Premium, YouTube, Google, Apple, App Store, Google Play, JLPT, N5–N1, TikTok, Instagram, Reddit, iPhone, Android.
5. Count strings come in a singular and a plural key ("{{n}} clip" / "{{n}} clips"): translate each correctly for its own form (the same text is fine where {L['name']} has no plural).
6. Buttons and tab labels must stay short. Fragments (e.g. 'tomorrow', 'in the morning') are inserted into a sentence described in the note: make them fit that sentence.
7. Japanese-learning terms: {L['glossary'][:1500]}
8. Output only the requested JSON."""


def item_line(i, k, en, extra=None):
    d = {"id": i, "en": en, "screen": where(k)}
    n = note_for(k)
    if n:
        d["note"] = n
    if extra:
        d.update(extra)
    return json.dumps(d, ensure_ascii=False)


SCHEMA_T = {"type": "object", "additionalProperties": False, "required": ["items"], "properties": {"items": {"type": "array", "items": {
    "type": "object", "additionalProperties": False, "required": ["id", "t"], "properties": {"id": {"type": "integer"}, "t": {"type": "string"}}}}}}
SCHEMA_R = {"type": "object", "additionalProperties": False, "required": ["fixes"], "properties": {"fixes": {"type": "array", "items": {
    "type": "object", "additionalProperties": False, "required": ["id", "t", "why"], "properties": {"id": {"type": "integer"}, "t": {"type": "string"}, "why": {"type": "string"}}}}}}


def translate_batch(lang, batch, table, retry_notes=None):
    lines = []
    for i, k in batch:
        extra = {"fix": retry_notes[k["key"]]} if retry_notes and k["key"] in retry_notes else None
        lines.append(item_line(i, k, k["key"], extra))
    prompt = "Translate each item's `en` into " + tc.STYLE["langs"][lang]["name"] + ". Items with `fix` failed an automatic check last time: fix exactly that.\nReturn {\"items\":[{\"id\":…, \"t\":…}]} with every id.\n\n" + "\n".join(lines)
    res = tc.call(system(lang), prompt, SCHEMA_T, "ui_translation", f"ui-{lang}-translate", effort="medium", model=TRANSLATE_MODEL)
    got = {it["id"]: it["t"] for it in res.get("items", [])}
    bad = {}
    for i, k in batch:
        t = got.get(i)
        pr = problems(lang, k["key"], t, note_for(k)) if t is not None else ["missing"]
        if pr:
            bad[k["key"]] = "; ".join(pr)
        else:
            with _lock:
                table[k["key"]] = t
    return bad


def run_translate(lang, limit_credits):
    ks = keys()
    table = load(lang, "translated")
    todo = [(i, k) for i, k in enumerate(ks) if k["key"] not in table]
    print(f"[{lang}] translate {len(todo)} of {len(ks)}", flush=True)
    notes = {}
    for attempt in range(3):
        if not todo:
            break
        batches = [todo[j:j + 40] for j in range(0, len(todo), 40)]
        failed = {}
        with cf.ThreadPoolExecutor(6) as ex:
            for bad in ex.map(lambda b: translate_batch(lang, b, table, notes), batches):
                failed.update(bad)
                save(lang, "translated", table)
                if tc.spent() > limit_credits:
                    raise SystemExit(f"credit limit {limit_credits} reached")
        notes = failed
        todo = [(i, k) for i, k in enumerate(ks) if k["key"] in failed]
        print(f"[{lang}] attempt {attempt + 1}: {len(failed)} failed checks", flush=True)
    for k, why in notes.items():
        print(f"[{lang}] STILL FAILING {k!r}: {why}", flush=True)
    save(lang, "translated", table)
    return len(notes)


def term_sheet(ks, table):
    """Key terms every chunk must stay consistent with (tabs, word levels, core buttons)."""
    core = ["Feed", "Explore", "Vocab", "Profile", "New", "Recognized", "Familiar", "Almost known", "Known", "Ignored", "Learning",
            "Save word", "Ask Kizuki", "Premium active", "Streak", "Words", "Review my words", "Explain", "Meaning", "Examples", "Notes",
            "Continue", "Settings", "Daily goal", "Watch clips", "Saved clips", "Help & support", "Restore purchase", "Sign in", "Remembered", "Forgot"]
    return {t: table[t] for t in core if t in table}


def review_chunk(lang, chunk, table, sheet):
    lines = [item_line(i, k, k["key"], {"current": table[k["key"]]}) for i, k in chunk]
    prompt = f"""You are the second, independent reviewer of this {tc.STYLE['langs'][lang]['name']} interface translation. For each item compare `en` (with its screen and note) to `current`.
Return a fix only when `current` is wrong, unnatural for a native {tc.STYLE['langs'][lang]['name']} app, inconsistent with the term sheet, the wrong form (plural/singular, button vs sentence), too long for a button/tab, or breaks a rule (placeholders, [ ], **, emoji, Japanese, line breaks). Do not rewrite items that are already good; do not change style for taste.
`why` = one short English sentence naming the problem.
Term sheet (keep these terms consistent everywhere): {json.dumps(sheet, ensure_ascii=False)}

{chr(10).join(lines)}"""
    res = tc.call(system(lang), prompt, SCHEMA_R, "ui_review", f"ui-{lang}-review", effort="medium", model=REVIEW_MODEL)
    applied, rejected = [], []
    by_id = dict(chunk)
    for fx in res.get("fixes", []):
        k = by_id.get(fx["id"])
        if not k or fx["t"] == table.get(k["key"]):
            continue
        pr = problems(lang, k["key"], fx["t"], note_for(k))
        if pr:
            rejected.append({"key": k["key"], "proposed": fx["t"], "why": fx["why"], "check": pr})
            continue
        applied.append({"key": k["key"], "from": table[k["key"]], "to": fx["t"], "why": fx["why"]})
        with _lock:
            table[k["key"]] = fx["t"]
    return applied, rejected


def run_review(lang, limit_credits):
    ks = keys()
    translated = load(lang, "translated")
    missing = [k["key"] for k in ks if k["key"] not in translated]
    if missing:
        raise SystemExit(f"[{lang}] {len(missing)} keys not translated yet: run translate first")
    reviewed = load(lang, "reviewed")
    table = dict(translated)
    table.update({k: v for k, v in reviewed.get("table", {}).items() if k in translated})
    done = set(reviewed.get("done", []))
    sheet = term_sheet(ks, table)
    todo = [(i, k) for i, k in enumerate(ks) if k["key"] not in done]
    chunks = [todo[j:j + 70] for j in range(0, len(todo), 70)]
    log = reviewed.get("log", [])
    with cf.ThreadPoolExecutor(4) as ex:
        for chunk, (applied, rejected) in zip(chunks, ex.map(lambda c: review_chunk(lang, c, table, sheet), chunks)):
            log += [dict(a, status="applied") for a in applied] + [dict(r, status="rejected") for r in rejected]
            done.update(k["key"] for _, k in chunk)
            save(lang, "reviewed", {"table": table, "done": sorted(done), "log": log})
            if tc.spent() > limit_credits:
                raise SystemExit(f"credit limit {limit_credits} reached")
    a = sum(1 for x in log if x["status"] == "applied")
    r = sum(1 for x in log if x["status"] == "rejected")
    print(f"[{lang}] review: {a} corrections applied, {r} proposals rejected by checks", flush=True)


def messages_call(system_text, prompt, schema, tag):
    """Claude through the gateway's native Messages API (streamed), returning parsed JSON."""
    import requests, time, random
    body = {
        "model": PROOF_MODEL, "max_tokens": 32000, "stream": True, "system": system_text,
        "messages": [{"role": "user", "content": prompt}],
        "thinking": {"type": "adaptive"},
        "output_config": {"effort": "medium", "format": {"type": "json_schema", "schema": schema}},
    }
    headers = {"Authorization": f"Bearer {os.environ['LOVABLE_API_KEY']}", "Content-Type": "application/json", "X-Lovable-AIG-SDK": "fetch"}
    last = None
    for attempt in range(5):
        try:
            with requests.post(f"{tc.GATEWAY}/messages", json=body, headers=headers, stream=True, timeout=(30, 900)) as r:
                if r.status_code in (402, 403):
                    raise tc.Terminal(f"HTTP {r.status_code}: {r.text[:300]}")
                if r.status_code != 200:
                    last = f"HTTP {r.status_code}: {r.text[:300]}"
                    if r.status_code in (429, 500, 502, 503, 504, 529):
                        time.sleep(min(120, 6 * 2 ** attempt) + random.random() * 3)
                        continue
                    raise tc.Terminal(last)
                text, usage, stop = [], {}, None
                for raw in r.iter_lines(decode_unicode=False):
                    line = raw.decode("utf-8", "replace") if raw else ""
                    if not line.startswith("data:"):
                        continue
                    ev = json.loads(line[5:].strip() or "{}")
                    t = ev.get("type")
                    if t == "content_block_delta" and ev["delta"].get("type") == "text_delta":
                        text.append(ev["delta"]["text"])
                    elif t == "message_start":
                        usage.update(ev["message"].get("usage") or {})
                    elif t == "message_delta":
                        usage.update(ev.get("usage") or {})
                        stop = (ev.get("delta") or {}).get("stop_reason") or stop
                    elif t == "error":
                        raise RuntimeError(json.dumps(ev)[:300])
                inp = (usage.get("input_tokens") or 0) + (usage.get("cache_creation_input_tokens") or 0)
                cached = usage.get("cache_read_input_tokens") or 0
                out = usage.get("output_tokens") or 0
                credits = inp * PROOF_PRICE["in"] + cached * PROOF_PRICE["cached"] + out * PROOF_PRICE["out"]
                with _lock, open(tc.ledger_path(), "a", encoding="utf-8") as f:
                    f.write(json.dumps({"tag": tag, "model": PROOF_MODEL, "in": inp, "cached": cached, "out": out, "credits": round(credits, 5)}) + "\n")
                if stop == "refusal":
                    raise tc.Terminal("model refused")
                if stop not in ("end_turn", "stop_sequence", None):
                    raise RuntimeError(f"stop_reason {stop}")
                return json.loads("".join(text))
        except tc.Terminal:
            raise
        except Exception as e:
            last = repr(e)[:300]
            time.sleep(min(90, 5 * 2 ** attempt) + random.random() * 3)
    raise RuntimeError(last or "failed")


def proof_chunk(lang, chunk, table, sheet):
    name = tc.STYLE["langs"][lang]["name"]
    lines = [item_line(i, k, k["key"], {"current": table[k["key"]]}) for i, k in chunk]
    prompt = f"""Final proofread before release. You are a native {name} speaker and professional UI copy editor. Each item: English source `en`, where it appears (`screen`, `note`) and the shipped {name} text `current`.
Return a fix ONLY for real problems a native user would notice: grammar or spelling mistakes, unnatural or machine-like wording, wrong meaning, wrong register for this app, terms inconsistent with the term sheet or with each other, a button/tab that is too long, a fragment that would not fit the sentence its note describes. Keep {{placeholders}}, [ ], **, emoji, Japanese and line breaks exactly. If an item is fine, leave it out. `why` = one short English sentence.
Term sheet: {json.dumps(sheet, ensure_ascii=False)}

{chr(10).join(lines)}"""
    res = messages_call(system(lang), prompt, SCHEMA_R, f"ui-{lang}-proof")
    applied, rejected = [], []
    by_id = dict(chunk)
    for fx in res.get("fixes", []):
        k = by_id.get(fx["id"])
        if not k or fx["t"] == table.get(k["key"]):
            continue
        pr = problems(lang, k["key"], fx["t"], note_for(k))
        if pr:
            rejected.append({"key": k["key"], "proposed": fx["t"], "why": fx["why"], "check": pr})
            continue
        applied.append({"key": k["key"], "from": table[k["key"]], "to": fx["t"], "why": fx["why"]})
        with _lock:
            table[k["key"]] = fx["t"]
    return applied, rejected


def run_proof(lang, limit_credits):
    ks = keys()
    reviewed = load(lang, "reviewed")
    if len(reviewed.get("done", [])) < len(ks):
        raise SystemExit(f"[{lang}] review not finished")
    proofed = load(lang, "proofed")
    table = dict(reviewed["table"])
    table.update({k: v for k, v in proofed.get("table", {}).items() if k in table})
    done = set(proofed.get("done", []))
    sheet = term_sheet(ks, table)
    todo = [(i, k) for i, k in enumerate(ks) if k["key"] not in done]
    chunks = [todo[j:j + 130] for j in range(0, len(todo), 130)]
    log = proofed.get("log", [])
    with cf.ThreadPoolExecutor(3) as ex:
        for chunk, (applied, rejected) in zip(chunks, ex.map(lambda c: proof_chunk(lang, c, table, sheet), chunks)):
            log += [dict(a, status="applied", stage="proof") for a in applied] + [dict(r, status="rejected", stage="proof") for r in rejected]
            done.update(k["key"] for _, k in chunk)
            save(lang, "proofed", {"table": table, "done": sorted(done), "log": log})
            if tc.spent() > limit_credits:
                raise SystemExit(f"credit limit {limit_credits} reached")
    a = sum(1 for x in log if x["status"] == "applied")
    print(f"[{lang}] proof: {a} corrections applied, {sum(1 for x in log if x['status'] == 'rejected')} rejected by checks", flush=True)


def run_store(lang):
    ks = keys()
    reviewed = load(lang, "reviewed")
    proofed = load(lang, "proofed")
    if len(proofed.get("done", [])) >= len(ks):
        reviewed = {"table": proofed["table"], "done": proofed["done"], "log": reviewed.get("log", []) + proofed.get("log", [])}
    else:
        print(f"[{lang}] WARNING: storing without the final proofread", flush=True)
    table = dict(reviewed.get("table", {}))
    done = set(reviewed.get("done", []))
    ov_path = os.path.join(UI, "overrides.json")
    overrides = (json.load(open(ov_path, encoding="utf-8")) if os.path.exists(ov_path) else {}).get(lang, {})
    for k, v in overrides.items():
        if k in table:
            table[k] = v
    out, bad = {}, []
    for k in ks:
        t = table.get(k["key"])
        if t is None or k["key"] not in done:
            bad.append((k["key"], "not reviewed"))
            continue
        pr = problems(lang, k["key"], t, note_for(k))
        if pr:
            bad.append((k["key"], pr))
            continue
        out[k["key"]] = t
    if bad:
        for b in bad[:20]:
            print(f"[{lang}] NOT STORED {b}", flush=True)
    path = os.path.join(UI, f"{lang}.json")
    json.dump(dict(sorted(out.items())), open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    open(path, "a", encoding="utf-8").write("\n")
    log = [x for x in reviewed.get("log", []) if x["status"] == "applied"]
    json.dump(log, open(os.path.join(UI, f"{lang}.review.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"[{lang}] stored {len(out)}/{len(ks)} → scripts/i18n/ui/{lang}.json ({len(log)} reviewer corrections logged)", flush=True)
    return len(bad)


def status():
    ks = keys()
    for lang in LANGS:
        t = load(lang, "translated")
        r = load(lang, "reviewed")
        s = os.path.join(UI, f"{lang}.json")
        stored = len(json.load(open(s, encoding="utf-8"))) if os.path.exists(s) else 0
        pf = load(lang, "proofed")
        print(f"{lang}: translated {sum(1 for k in ks if k['key'] in t)}/{len(ks)}, reviewed {len(r.get('done', []))}, proofread {len(pf.get('done', []))}, stored {stored}")
    print(f"ledger total {tc.spent():.1f} credits")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["translate", "review", "proof", "store", "all", "status"])
    ap.add_argument("--lang", choices=LANGS)
    ap.add_argument("--max-credits", type=float, default=2900)
    a = ap.parse_args()
    if a.cmd == "status":
        return status()
    langs = [a.lang] if a.lang else LANGS
    if a.cmd == "all":
        def one(lang):
            run_translate(lang, a.max_credits)
            run_review(lang, a.max_credits)
            run_proof(lang, a.max_credits)
            return run_store(lang)
        with cf.ThreadPoolExecutor(len(langs)) as ex:
            bad = list(ex.map(one, langs))
        print("done; unstored per language:", dict(zip(langs, bad)))
        return
    for lang in langs:
        if a.cmd == "translate":
            run_translate(lang, a.max_credits)
        elif a.cmd == "review":
            run_review(lang, a.max_credits)
        elif a.cmd == "proof":
            run_proof(lang, a.max_credits)
        else:
            run_store(lang)


if __name__ == "__main__":
    main()
