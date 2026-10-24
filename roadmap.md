# Kizuki roadmap (Kiku-beating Japanese immersion app)

Flutter (`mobile/`) is the product; the web app is its phone-frame prototype.
Name: **Kizuki (気づき)** — "the moment it clicks". Public repo: github.com/pranacodes-cmyk/kizuki

## Starter clips, faster video start, word levels + new store build (24 Oct)
- [x] Word level badges: Waller's JLPT list ids pointed basic words at side entries (これ N5 → "hey"), greetings sat in N3–N2 — now matched by id + spelling + textbook fixes (おはよう/こんにちは/ありがとう/これ/さん → N5). Found on the way: grammar words used kanji nouns' meanings (の = 野 "field", た = 田 "rice field", ます = 増す) — matching is now part-of-speech aware. Guarded by content tests.
- [x] Library checked through the official player (all 1,150 videos): 31 videos refuse embedding, 309 had AI timestamps past the real video end (stretched timing, subtitles out of sync). Re-timed all 309 with the real length: 167 fixed, 142 still wrong and excluded. Library now 2,562 clips / 975 videos, every clip inside its real video; content test fails if a broken window ships.
- [x] Starter feed: AI watched ~620 candidate clips and rated them as first clips; 48 picked (37 N5, 11 N4, 44 channels), each verified playing; an AI editor ordered them for variety. Same order for everyone in the onboarding phone preview and the first home feed (until watched / 60 watched clips; N2+ learners skip very easy ones). The old greetings showcase left with its mistimed video; the top-rated clip opens now.
- [x] Faster video start: next clip's player loads and cues in the background (both apps, never plays hidden), YouTube player code loads during the splash, early connections, "Slow connection · Tap to retry" after 9 s, pause-before-ready fixed. 480p cannot be forced (YouTube ignores quality requests in embeds; a phone-size player already gets ~360–480p).
- [x] Checks: Flutter analyze clean + 132 tests, web 118 tests + typecheck, browser walk (tour, feed, trial preview show the same first clip, 2 players in feed / 1 in preview, no errors).
- [ ] Android emulator test + store upload (Play internal + TestFlight) of this build — in progress.
- [ ] Re-time the 142 still-stretched videos another way (e.g. shorter segments) or replace them with new videos to get back above 1,000 videos.
- [ ] Real-phone check of video start speed with the warm-up (cannot be measured here).

## Simple welcome tour + plain review words (24 Oct, from phone screenshots)
- [x] Tour cut from 19 to 12 do-what-I-point steps, Flutter first then web: no subtitles/green-box step (it lit the video), no button list, no Explore detour.
- [x] Word card steps light the whole card (meaning stays readable) with the hand on Explain / Ask Kizuki; Ask Kizuki step has a "Back to the video" button that closes both cards itself (no "tap above each card"); closing a card by hand never gets stuck.
- [x] Spotlights only count the visible part of a target (scrolled-away words never light the video); tour word scrolls into view and the clip pauses.
- [x] Simple 3-row line legend (blue new · orange saved · no line known); last step "Back to videos" returns to the feed instead of leaving the learner on the review card.
- [x] Review: Forgot / Remembered with icons, no "1m / 10m" codes; "Did you remember it?"; finished screen explains words come back at the right time; level sheet + saved-word card say "Next practice in 10 minutes".
- [x] One word-status vocabulary: Learning / Known everywhere (Vocab "Mastered" and kana "learned" renamed).
- [x] Bug found in the walk: pausing a clip that was still loading crashed the web feed ("Something went wrong") — both players now queue the pause until playback starts; web regression test added.
- [x] Mirrored tests (tour machine, plain-time wording) + Flutter analyze/tests, web tests/typecheck, browser walk of the whole tour at phone size (412×880), 4/4 repeated starts without errors.
- [ ] Real-phone check of the new tour + Android emulator tour test: runs in the next store build (none uploaded in this task).
- [x] Content check: JLPT badges fixed (see Starter clips section).

## Premium motion + haptics (24 Oct)
- [x] Living fox: shared mirrored motion math (breathe / float / groove idle, spring entrance, squash-and-stretch hop, tap boop); entrances wait for the splash; reduced motion freezes it. Flutter first, then web.
- [x] Animated splash in both clients (fox pop, orange "click" ripples, letter-by-letter wordmark, tagline) + native Android/iOS launch screens on pure black with the same-size fox face (no colour jump).
- [x] Plan-building ring: gentle ratchet ticks every 5%, light tap at each step, success the moment it reads 100% with fox cheer + ring pulse; ring head glow; plan screen celebrates with confetti.
- [x] Onboarding: progress fox hops forward, answer cards pop with check badges, slider ticks, method/streak fox reacts.
- [x] App-wide semantic haptics (buttons, toggles, tabs, word taps, saves, review grades, paywall, achievements, errors) with Settings → Vibration feedback (default on); mirrored pulse tables + tests.
- [x] Verified: Flutter analyze clean, 125 Flutter tests; 107 web tests, typecheck + preview build OK; browser walk of splash, welcome, onboarding, building (21 pulses: 16 ticks, 3 steps, success, plan celebration), plan, trial, settings toggle — no page errors.
- [ ] Real-phone feel check (vibration strength, splash handoff on Android 12+/iOS) in the next store build — none uploaded yet; waits on the user asking for a new Play/TestFlight release.

## Ask Kizuki tour + subscription clarity (24 Oct)
- [x] Add Ask Kizuki opening, explanation and closing to the word-card tour, Flutter first then web; keep Ask button first in Explain so small phones can reach it; no automatic paid AI request.
- [x] Subscription settings show Premium active with actual trial end when applicable, never another unconditional trial offer; monthly simulation no longer creates a seven-day trial.
- [x] 88 web tests pass, preview build OK. Browser walks actual word→Explain→Ask tour at 384×624; simulated monthly checkout persists trialEndsAt=null and settings reads Premium active, yearly reads trial end. Account gate bypassed only in browser verification to inspect settings, not an authenticated store purchase test.
- [x] Native tests: Flutter SDK now runs here; analyze clean, 125 Flutter tests pass (24 Oct).
- [ ] Live store offer verification and real purchase: needs a phone with the next store build.

## Clip playback + onboarding showcase (24 Oct)
- [x] Root cause verified through official embed: weather segment starts at 303.1s but actual source duration is 301s. Exclude invalid segment via content pipeline; both clients now ship 3,036 clips / 1,150 videos.
- [x] Flutter first, then web: reject clip windows beyond loaded source duration, stop misleading playback; startup correction waits for genuine advancing out-of-range timestamps and ignores stale zero events. Mirrored regression tests added; 86 web tests pass, preview build OK.
- [x] Every trial preview starts with Essential Daily Greetings (N5, 17s), followed by personalized clips. Official embed playback verified 12.09→14.62→17.13s, active transcript changes Good morning→Hello; 384×624 preview checked, no page errors.
- [x] Native regression tests pass (125 Flutter tests, 24 Oct).
- [ ] Physical-phone playback check: needs the next Play/TestFlight build.

## Launch audit + privacy policy + store update (23 Oct)
- [x] Flutter SDK running in the sandbox (certificate fix); flutter analyze clean, 99 Flutter tests + 82 web tests pass
- [x] Sync: a cloud sync started for one account can no longer be merged into or uploaded under another account (both clients, Flutter tests)
- [x] Settings → Restore purchase and paywall purchases always go through the mandatory account step; back/skip blocked while a purchase runs
- [x] Reminder start-up race fixed (reminders no longer silently skipped at launch)
- [x] Returning subscribers aren't promised a free week; live prices/eligibility redraw an open paywall
- [x] Small phones (360×640, large system text): onboarding + paywall buttons pinned, content scrolls with a fade, plans shown before perks; Flutter widget tests + web walk at 360×640 and 384×624
- [x] New full Privacy Policy (14 sections: data, uses, providers, Meta/ATT, retention, rights, deletion without the app, children, transfers) + Terms contact; same text in both clients (generated + parity test); Help answer for deleting without the app
- [x] Store builds: GitHub run 40006801363 green (analyze + tests) → Android 1.2.0 (109) rolled out to Play internal testing (replaces 108); iOS 1.2.0 (109) VALID, in TestFlight for the Kizuki team group; new policy live at /privacy (read back)
- [x] Build 1.2.0 (111) (24 Oct): Play internal testing rolled out; TestFlight VALID, in internal testing for Kizuki team. Emulator flow test stopped on request — not re-run since billing fix.
- [ ] App Store privacy answers + Play Data safety must match the new policy (by hand in the consoles)
- [ ] Legal review of the policy by a lawyer (written by me from what the app does; not legal advice)
- [ ] Real-phone retest of build 109 (Android + iPhone): purchase → account, reminders, small-screen paywall


## Founder model comparison (23 Oct)
- [x] Founder video reduced to max 180×320 with learning highlights, Flutter first then web; phone preview shows video, highlights and Continue to trial with no page errors. Flutter visual check pending because Flutter SDK is unavailable.
- [x] Removed added story/AI label in v8; speech, expressions and orange captions unchanged. Flutter bundled master replaced first, then web MP4/WebM/poster pointers; beginning/middle/end frames inspected, phone video and Continue verified without page errors, preview build OK. No new store build requested.
- [x] Approved first version: captions enlarged from 39 to 51px with orange impactful words; 40.07s master compressed to 3.55 MB (about 38% smaller). Flutter bundled file replaced first, then web asset pointers with same-caption WebM fallback; old app overlays disabled during video playback. Phone preview verified at 384×624, Continue reaches trial, no page errors; all 80 web tests pass and preview build OK. Flutter SDK absent: native checks/new store build not performed.
- [x] Softer natural-expression export (40.07s, 5.7 MB), Seedance comparison (60.22s) and Omni comparison (60.62s) exported with timed captions and AI-fiction disclosure; grouped in Files.
- [x] Same source persona used across parallel generations; sampled beginning/middle/end frames checked, speech machine-transcribed. These are comparison drafts: independent clips can vary in voice/expression and joins; no full lipsync listening review.
- [ ] Veo 3 version blocked: the available generation tool exposes only Seedance and Omni.
- [x] Present comparison files honestly as AI dramatizations; no app integration or store upload requested.

## Word-first cards and simpler vocabulary (23 Oct)
- [x] Flutter first: word/meaning/sentence cards; original video opens only on request; Forgot / Remembered choices.
- [x] Mirror web; Learning / Known / Ignored controls, All / To Review / Mastered tabs, JLPT clip badges; saved SRS thresholds unchanged.
- [x] 79 existing web tests plus the new familiarity regression test pass (80 total), preview build OK; 384×624 browser flow verifies reveal, zero video iframes before request, optional context sheet and persisted review grading.
- [x] Flutter analyze/tests pass (24 Oct).
- [ ] Physical Android/iPhone check: needs the next store build.

## AMOLED and onboarding polish (23 Oct)
- [x] Mirror pure-black/neutral-surface/orange tokens, Flutter first, then web.
- [x] Remove the name question; make categories fully reachable and refine plan celebration/step motion.
- [x] Require sign-in after purchase/restore, preserve purchase on login, and save owner-only profiles.
- [x] All 79 web tests pass. At 384×624, all categories reachable; nine questions go directly to building; simulated checkout cannot skip login or reopen feed; verified account reaches feed with Premium retained and profile preferences read back. No browser page errors.
- [x] Flutter analyze/tests pass (24 Oct).
- [ ] Physical Android/iPhone checks and a fresh confirmed-signup test: need the next store build and a real new account.

## Playback restart fix (23 Oct)
- [x] Remove repeated startup seeks and guard loop/replay seeks until YouTube acknowledges the new position; Flutter first, then web. Allow only a one-time correction if YouTube ignores the requested start.
- [x] Add 4 mirrored guard tests plus an actual web-player command regression test; all 77 web tests pass, preview build OK.
- [x] Flutter tests pass (24 Oct).
- [ ] Real-phone playback retest: new signed phone build needed. Browser video advances 0→20s without a 1-second restart, but ignores clip-start commands and app timer remains 0:00 in this environment, so correct-range playback is not verified.

## Production launch round (22 Oct, goal run)
- [x] Play: release AAB uploaded to the internal track (now 1.2.0 (109))
- [x] Apple: macOS GitHub workflow → TestFlight build (now 1.2.0 (109))
- [x] Store listing text (store/listing.json, within every store limit): App Store name, subtitle, 99-char keywords, promo text, description, categories Education/Reference, age rating, support/privacy/marketing URLs, version 1.0.0 — pushed to App Store Connect
- [x] Google Play listing saved (contact email pranacodes@gmail.com + /support website, text, icon, feature graphic, 6 screenshots); read back from Play
- [x] Help & support page in both apps (common questions + message form saved to the backend), Profile → Help & feedback, Settings → Help & support + Restore purchase; final Terms/Privacy (draft banner removed, auto-renew terms, AI tutor + help messages in privacy); Terms/Privacy links on the paywall; website tab icon
- [x] Website publish requested (user's go-ahead 22 Oct) so Support/Terms/Privacy are live before review
- [x] Android signing key details (base64, alias, password, SHA-256) handed to the user as a private text file in Files; same key forever
- [x] App Store version record renamed 1.0.0 → 1.2.0 to match the app's version name
- [ ] App Store Connect by hand: App Privacy answers, App Review contact (name/phone/email); Play by hand: App content forms (Data safety, content rating, target audience, ads)
- [x] Store art: Play icon 512, Play feature graphic 1024×500, 6 captioned screenshots each for iPhone 6.9" (1290×2796, uploaded to App Store Connect) and Play (1080×1920); re-render with scripts/stores/screenshots
- [ ] Meta max setup: SKAdNetwork IDs, privacy manifest, ATT asked after the app opens (iOS), full app-event set (no double counting with RevenueCat), RevenueCat device IDs after ATT
- [x] Founder video: user's own story, captions, in both clients
- [ ] Full audit of the Flutter app (crashes, logic, performance, UX) + fixes mirrored on web

## Phone screenshots round 3 (tour + review card, 22 Oct) — no APK this round
- [x] Review flashcard rebuilt like Kiku's: whole card is the tap target (no "Show answer"), card flips, Definition (clip meaning only when it adds something) + Context (original clip, highlighted sentence, Open the clip), Again/Good appear only after the flip, swipe still works
- [x] Word levels like Kiku (1 New, 2 Recognized, 3 Familiar, 4 Almost known, Known, Ignored): rise with reviews, one level button + sheet on word card and saved-word sheet, badge in Vocab list, underline fades orange to brown
- [x] Word card: cramped Learning/Known/eye/trash row replaced by level button + "I know it"/"Learn again"; Android sheets keep clear of the nav bar
- [x] Tour: meaning/explain tips sit above the word card (card fully lit); legend drawn like real words incl. green "being said" box; controls step lists every button with its icon; "Aa" button; step counter instead of "Tap anywhere"; whole flashcard spotlit with tip on its empty lower part; short grade tip that leaves the sentence visible; tour word is a real content word (never ん/particles)
- [x] YouTube's own captions also switched off in the flashcard/saved-word clip player (code done; real-phone check pending)
- [x] Mirrored tests: levels, duplicate-meaning, tour-word pick, tour placement, flashcard + level-sheet widget tests. Flutter analyze clean, 84 Flutter tests + 68 web tests pass; web tour walked end-to-end in a phone-size browser
- [ ] Android emulator run of the new flashcard/tour (needs a CI run; user asked for no APK this round)
- [ ] Level thresholds (10 min / 3 days / 10 days, Known at 21 days) are my choice; confirm with the user

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
- [x] Library round 3: 952 videos / 2,507 clips (N5 510, N4 942, N3 987, N2 64, N1 4), all proofread + word notes; 63 web tests pass. Flutter tests/APK not re-run (user asked to focus on content).
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

## Store setup
- [x] Apple bundle identifier com.kizukijapan.app registered (team key)
- [x] RevenueCat V2 key saved; Android + iOS public SDK keys fetched and saved
- [x] Wire RevenueCat + Meta SDK into Flutter
- [x] Privacy policy: mention Meta + RevenueCat, tracking opt-out
- [x] App Store + Play subscriptions created (yearly 7-day trial, monthly), prices in all countries; RevenueCat entitlement/offering wired
- [x] RevenueCat SDK in Flutter: live prices, buy, restore, status sync; iOS project created (com.kizukijapan.app)
- [x] iOS build/upload via macOS GitHub workflow
- [ ] E2E: emulator has no store account; build E2E APK with --dart-define=KIZUKI_SIMULATE_PURCHASES=true
