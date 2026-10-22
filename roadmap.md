# Kizuki roadmap (Kiku-beating Japanese immersion app)

Flutter (`mobile/`) is the product; the web app is its phone-frame prototype.
Name: **Kizuki (気づき)** — "the moment it clicks". Public repo: github.com/pranacodes-cmyk/kizuki

## Research
- [x] Frame-by-frame teardown of the user's Kiku recording (docs/kiku-teardown.md)
- [x] Founder video transcript + timing
- [x] Product spec + simplifications (docs/product-spec.md)

## Content pipeline
- [x] Hand-picked YouTube videos by topic (227 embeddable videos used)
- [x] AI clip finder + verbatim transcript with timings
- [x] Proofreading pass, tokens + furigana + romaji, JMdict senses, JLPT levels
- [x] Per-word explain-in-context + per-line notes (precomputed for every clip, re-made when a line's words change)
- [x] Family-friendly dictionary filter (vulgar senses / crude examples dropped)
- [x] Same JSON for web (public/data) + Flutter (mobile/assets/data)
- [x] Beginner round 1: 32 kids'-show / easy-Japanese videos → N5 47 → 81
- [x] Beginner round 2: 65 comprehensible-input / folk-tale / kids' videos → 594 clips, N5 207, N4 225, N3 152, N2 10
- [x] Word splitting: long vowels (ー) stay with their word; numbers + counters are one word with the right reading (いっぷん, じゅっぷん, さんぜんねん…)
- [x] Pinned dictionary download (scripts/content/fetch_dict.sh) so the pipeline re-runs from scratch
- [x] Automated timing audit (order, bounds, durations, speed); lines never overlap the next line
- [ ] Listen-through spot-check of a sample of clips by a person

## Shared rules (logic.ts / logic.dart, mirrored tests)
- [x] Plan, ranking, SRS, streaks, goals, achievements, search, kana, sync merge
- [x] Free tier (10 clips/day), "hear it in other clips", kana queue, keep studying
- [x] Ask Kizuki rules: 5 free questions/day (premium unlimited), 400-char questions, last 10 messages sent

## Web prototype
- [x] Welcome → onboarding (10 steps) → building → plan → founder → paywall (3 steps) → account
- [x] Feed: YouTube player, karaoke transcript, word card (Meaning/Explain/Examples/Notes), daily goal, line menu, Aa sheet
- [x] Explore, Vocab, Review, Profile, Settings, History, Saved, Achievements, Terms, Privacy
- [x] Email + Google + Lovable sign-in, password reset, cloud sync, delete account
- [x] Welcome tour on the feed (7 steps) + replay in Settings
- [x] Ask Kizuki chat (word card Explain tab + line menu), streamed AI answers, sign-in + daily-limit states
- [x] Kizuki branding on splash + welcome ("気づき · the moment it clicks")
- [x] Paywall perks mention the AI tutor (both clients)

## Flutter app (same screens)
- [x] App shell, theme, fonts, assets, router
- [x] Onboarding → plan → founder → paywall → account (email/password only on Android)
- [x] Feed / Explore / Vocab / Review / Profile / Settings / History / Saved / Achievements
- [x] Welcome tour (same steps as web)
- [x] Sync service, reminders (local notifications), TTS, rate prompt, CSV share
- [x] App icon + splash
- [x] Ask Kizuki chat (same sheet as web; talks to the published web app)
- [x] Blank-screen fix: release builds no longer shrink plugin code (saved progress failed to load → blank app); startup shows UI first, backend connects in the background
- [ ] Google / Lovable sign-in on Android (needs native OAuth redirect setup)

## Android delivery
- [x] flutter analyze + flutter test clean (54 Flutter tests, 43 web tests)
- [x] GitHub Actions: analyze → test → release APK → Android emulator end-to-end (release smoke + full flow with screenshots)
- [x] Release APK on the emulator: opens to the welcome screen, saved-progress error gone (run 39691375925)
- [x] Emulator watcher closes system pop-ups (launcher "isn't responding") that covered the app
- [x] Emulator end-to-end run green on GitHub (run 39697658751): release APK opens and moves into onboarding; full flow welcome → onboarding → plan → founder → paywall → feed with YouTube → word card → Ask Kizuki → Vocab → Review → Explore → Profile → Settings
- [x] Emulator caught + fixed: cards now open above the tab bar; word card closes without an error
- [x] Final APK from the green run → Files (Kizuki-1.1.0.apk)
- [ ] Test on a real Android phone

## Needs the user
- Publish the web app — Ask Kizuki in the phone app and the email links (confirm / reset password) use the published address
- Install the APK on a real phone and report anything broken
- Real founder recording (recording guide in Files: founder-video-guide.md)
- Real prices / Play billing products, Play signing keystore
- Real support email (hello@kizuki.app is a placeholder)
- Legal review of Terms / Privacy drafts
