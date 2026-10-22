# Kizuki roadmap (Kiku-beating Japanese immersion app)

Flutter (`mobile/`) is the product; the web app is its phone-frame prototype.
Name: **Kizuki (気づき)** — "the moment it clicks". Public repo: github.com/pranacodes-cmyk/kizuki

## Real-phone feedback round 1 (user screen recording, 22 Oct)
- [x] Feedback round 2: removed simulated preview animation/geometry callbacks; released founder decoder before trial; single-flight content loading; actual swipeable home ClipView in both clients. 75 Flutter tests + 63 web tests pass; green emulator run 39752455442 verifies trial swipes, trial activation → account, full tour, feed swipes and 0.00px wobble. APK 1.1.2 delivered. Exact original real-phone crash cause remains unconfirmed without phone logs; phone retest pending.
- [x] Name field: "Build my plan" + Skip stay fully above the keyboard (verified on the Android emulator with the real keyboard, 312px tall, and on web)
- [x] "Designing your course" progress bar → ring (both clients)
- [x] Feed jumps up/down as the transcript advances (transcript scrolls only itself now)
- [x] Welcome tour: 16 interactive steps across Feed, word card, Explore, Vocab, Review (web walked end-to-end; tap hand sits below the word; review spotlight on the word)
- [x] Swipe to next clip: one swipe anywhere = one clip (subtitles no longer eat swipes; web feed no longer bounces back while a clip plays); drag tests on both clients
- [x] Founder step: presenter video with voice + synced captions (generated presenter — not a real person; swap for a real recording before launch)
- [x] "$0 today" paywall step: phone mockup plays the learner's own first clips (thumbnail, karaoke, tap, card, swipe)
- [x] Trial mockup: lower half shows the next transcript lines like the real feed (repeated sentences skipped)
- [x] Word meanings: 119 katakana words had the wrong meaning (ホテル "to feel hot", クラス "to live", チョコ "sake cup"…) — fixed in the content build + data tests
- [x] Split katakana words joined back up (ガン+ダム "cancer"+"dam" → ガンダム, イヤホン, サブウェイ, カンフー…): 42 words in 31 clips, AI word notes re-made for those 31 clips; tests guard it
- [x] Android tour stuck on the Review step (the app didn't notice the pushed Review screen) — fixed + test
- [x] Every APK now signed with one fixed key (GitHub secret), so new versions install over old ones; version 1.1.1
- [x] Emulator run green on GitHub (run 39738357302): name screen with the real keyboard, presenter video, paywall demo, full 16-step tour, real finger swipes (5 up, 1 down, short drag springs back, quick flick), no wobble (0.00px over 10s)
- [x] New APK from the green run → Files (Kizuki-1.1.1.apk, fixed signing key)
- [ ] YouTube video actually playing on Android: GitHub emulator reaches buffering but does not advance; cause unconfirmed, real-phone check needed (web preview player renders and trial continuation verified).
- [x] Sweep of the phone recording: podcast videos (a still Patreon banner instead of video) now rank far down the feed (22 clips; never in a new learner's first 150); clips no longer open on the tail of the previous sentence (2 clips trimmed, notes re-made)

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
- [x] Welcome tour (16 steps across Feed, word card, Explore, Vocab, Review) + replay in Settings
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
- Real prices / Play billing products (a permanent signing key now exists and can be the Play upload key)
- Real support email (hello@kizuki.app is a placeholder)
- Legal review of Terms / Privacy drafts
