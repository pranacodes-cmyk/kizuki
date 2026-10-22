"""Builds a realistic learner state (mimi-state-v1) for store screenshots."""
import json, random, time
random.seed(7)
D = json.load(open('/dev-server/public/data/dict.json'))
C = json.load(open('/dev-server/public/data/content.json'))
clips = []
for p in C['parts']:
    clips += json.load(open('/dev-server/public/data/' + p))['clips']
by_id = {c['id']: c for c in clips}
now = int(time.time() * 1000)
day = 86400000
words = {}
pool = [c for c in clips if c['level'] in ('N5', 'N4') and c.get('quality', 0) >= 4]
random.shuffle(pool)
wanted = 46
for c in pool:
    for li, l in enumerate(c['lines']):
        for wi, w in enumerate(l['words']):
            d = w.get('d')
            if not d or w['p'] in ('particle', 'punct', 'auxiliary', 'conjunction') or d not in D: continue
            e = D[d]
            if not e.get('c') or e.get('j') not in (5, 4, 3): continue
            k = 'd' + d
            if k in words: continue
            g = e['m'][0]['g']
            if len(g) > 46: g = g[:46].rsplit(';', 1)[0]
            words[k] = dict(key=k, dictId=d, word=e['w'], reading=e['r'], romaji=w.get('ro', ''), gloss=g, pos=w['p'],
                            jlpt=e.get('j'), surface=w['s'], clipId=c['id'], line=li, idx=wi, note='', status='learning',
                            card=None, addedAt=0, updatedAt=0)
            break
        if len(words) >= wanted: break
    if len(words) >= wanted: break
ks = list(words)
for i, k in enumerate(ks):
    w = words[k]
    added = now - (24 - i // 2) * day
    w['addedAt'] = w['updatedAt'] = added
    if i < 12:   # known
        w['status'] = 'known'
        w['card'] = dict(state='review', step=0, interval=60, ease=2.7, due=now + 40 * day, reps=8, lapses=0)
    elif i < 22:  # familiar / almost known
        iv = [6, 9, 14, 21, 30][i % 5]
        w['card'] = dict(state='review', step=0, interval=iv, ease=2.5, due=now + (iv // 2) * day, reps=4, lapses=0)
    elif i < 34:  # due now
        w['card'] = dict(state='review' if i % 2 else 'learning', step=0, interval=2 if i % 2 else 0, ease=2.4, due=now - 3600000, reps=2, lapses=0)
    else:         # brand new
        w['card'] = dict(state='new', step=0, interval=0, ease=2.5, due=now - 60000, reps=0, lapses=0)

def dk(ts):
    t = time.localtime(ts / 1000)
    return f"{t.tm_year:04d}-{t.tm_mon:02d}-{t.tm_mday:02d}"
activity = {}
for back in range(0, 40):
    if back > 23 and random.random() < 0.5: continue
    activity[dk(now - back * day)] = dict(sec=random.randint(600, 1800), clips=random.randint(6, 18), reviews=random.randint(10, 40), words=random.randint(1, 5))
seen_ids = [c['id'] for c in pool[:180]]
ach = ["first-clip","clips-10","words-10","review-1","streak-3","time-30","clips-50","streak-7","words-50","time-60","known-25","streak-30"]
state = dict(
    version=1, onboarded=True,
    profile=dict(name='Aiko', reasons=['anime', 'travel'], level=1, jlpt='N4', challenges=['listening'], source='instagram',
                 fluencyMonths=12, dailyMinutes=15, window='evening', streakGoal=30),
    premium=dict(active=True, plan='yearly', since=now - 20 * day, trialEndsAt=None),
    words=words, kana={}, seen={cid: now - i * 3600000 for i, cid in enumerate(seen_ids)},
    history=[dict(clipId=cid, at=now - i * 3600000) for i, cid in enumerate(seen_ids[:40])],
    savedClips=seen_ids[:6], activity=activity, totals=dict(clips=sum(a['clips'] for a in activity.values()), seconds=sum(a['sec'] for a in activity.values()), reviews=sum(a['reviews'] for a in activity.values())),
    settings=dict(furigana=True, romaji=True, translation=True, spacing=True, highlight=True, autoSave=True, textSize=1, speed=1,
                  flashFront='jp', flashFurigana=False, flashRomaji=False, reminders=True, reminderFreq='standard'),
    tutorial=dict(feed=True, review=True), achievementsSeen=ach, feedSeed='store-shots', reviewSessions=31, ratingAsked=True,
    planModalSeen=True, asks=dict(day='', n=0), updatedAt=now,
)
json.dump({"state": state, "version": 0}, open('/tmp/browser/shots/seed.json', 'w'), ensure_ascii=False)
print(len(words), 'words;', len(activity), 'active days')
print([ (w['word'], w['gloss']) for w in list(words.values())[:8]])
