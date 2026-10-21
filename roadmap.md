# Mimi roadmap (Kiku-beating Japanese immersion app)

Flutter (`mobile/`) is the product; the web app is its phone-frame prototype.

## Research
- [x] Frame-by-frame teardown of the user's Kiku recording (docs/kiku-teardown.md)
- [x] Founder video transcript + timing
- [x] Product spec + simplifications (docs/product-spec.md)

## Content pipeline
- [x] 186 hand-picked YouTube videos by topic (162 embeddable used)
- [x] AI clip finder + verbatim transcript with timings (414 clips)
- [x] Proofreading pass, tokens + furigana + romaji, JMdict senses, JLPT levels
- [x] Per-word explain-in-context + per-line notes (precomputed, 414/414)
- [x] Family-friendly dictionary filter (vulgar senses / crude examples dropped)
- [x] Same JSON for web (public/data) + Flutter (mobile/assets/data)
- [x] Beginner round: 32 kids'-show / easy-Japanese videos → N5 47 → 81, N4 126 → 173
- [ ] Another beginner round to reach ~150 N5 clips
- [ ] Tidy word splitting for long vowels (ー) and digits in transcripts
- [x] Automated timing audit of the first 330 clips (order, bounds, durations, speed: clean; 6 fast-but-plausible lines)
- [ ] Listen-through spot-check of a sample of clips by a person

## Shared rules (logic.ts / logic.dart, mirrored tests)
- [x] Plan, ranking, SRS, streaks, goals, achievements, search, kana, sync merge
- [x] Free tier (10 clips/day), "hear it in other clips", kana queue, keep studying
- [x] Mirror the new rules (canWatchClip, clipsWithWord, kanaQueue, kanaLearned, customStudyKeys) + tests in Dart

## Web prototype
- [x] Welcome → onboarding (10 steps) → building → plan → founder → paywall (3 steps) → account
- [x] Feed: YouTube player, karaoke transcript, word card (Meaning/Explain/Examples/Notes), daily goal, line menu, Aa sheet
- [x] Explore: search word/text, level, topic, grammar
- [x] Vocab: counts, review button, decks (words/hiragana/katakana), search, filters, word sheet with original audio
- [x] Review (SRS, swipe, original clip line) + well done + plan modal + rate prompt
- [x] Profile, settings, history, saved, achievements, terms, privacy
- [x] Email + Google + Lovable sign-in, password reset, cloud sync, delete account
- [x] Welcome tour on the feed (7 steps: player, tap-a-word, underline legend, controls, swipe, Vocab) + replay in Settings
- [ ] Ask Mimi chat (AI follow-up questions, online)

## Flutter app (same screens)
- [x] App shell, theme, fonts, assets, router
- [x] Onboarding → plan → founder → paywall → account (email/password only on Android)
- [x] Feed / Explore / Vocab / Review / Profile / Settings / History / Saved / Achievements
- [x] Welcome tour (same steps as web)
- [x] Sync service, reminders (local notifications), TTS, rate prompt, CSV share
- [x] App icon + splash
- [ ] Google / Lovable sign-in on Android (needs native OAuth redirect setup)

## Android delivery
- [x] Flutter project + toolchain
- [x] flutter analyze + flutter test clean (45 Flutter tests, 39 web tests)
- [x] GitHub Actions APK workflow written (.github/workflows/android-apk.yml) — not yet run on GitHub
- [x] Local release APK build → /mnt/documents/Mimi-1.0.1.apk (414 clips, debug-signed, sideload only)
- [ ] Test on a real Android phone (no emulator available in the sandbox)

## Needs the user
- Install the APK on a real phone and report anything broken
- Change the email-link address (mobile/lib/services/config.dart) to the published web address after publishing
- Real founder recording (recording guide in Files: founder-video-guide.md)
- Final brand name, real prices / Play billing products, Play signing keystore
- Real support email (profile "Contact the founder" uses a placeholder)
- Legal review of Terms / Privacy drafts
