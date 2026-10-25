# Kizuki roadmap (Kiku-beating Japanese immersion app)

Flutter (`mobile/`) is the product; the web app is its phone-frame prototype.
Name: **Kizuki (気づき)** — "the moment it clicks". Public repo: github.com/pranacodes-cmyk/kizuki

## Corrections requested 25 Oct
- [x] Remove unsolicited usage-analytics popup from Flutter and web; optional tracking opt-in remains in Settings. Fresh web launch: 0 dialogs, 0 PostHog requests; privacy copy generated and parity test passes.
- [x] Restore native-only Google/Apple account code; remove remote-method selection and automatic browser launch. Native failure stays in-app; retain incoming legacy hand-offs. Three supplied IDs already present; previous promise to finish provider setup was incomplete.
- [x] Start bootstrap and content preparation concurrently, Flutter first then web. Test proves notes prepare while API is pending. Web preview at 384×624 plays to 0:08/0:17 after 10 s, 1 official player, no runtime errors; 0 players before trial.
- [x] Web: 146 tests pass; latest local preview build OK. No new store build or publication this turn.
- [ ] Native provider acceptance: own Google/Apple backend audiences/settings cannot be inspected/changed by offered config tools; needs owner Cloud Auth settings read/configuration. No native token exchange verified; do not ship as working native login.
- [ ] Native checks / trial speed: Flutter SDK absent in this sandbox; Flutter analyze/tests and physical-phone startup/login measurements pending. Concurrent bootstrap is not actual prebuffering; hidden players/downloaded YouTube media remain prohibited.
- [ ] Android-only release (user, 25 Oct): sync latest code to public GitHub repo with saved token (as before), run Store release with android=true, ios=false.

## Pre-release deep check + new store build (24 Oct, user request)
- [x] Flutter analyze error: app_links `getInitialUri` replaced by `getInitialLink` (analyze clean)
- [x] Stale Flutter Ask tests updated to the Premium-only tutor; leftover "free questions left" footer removed in both clients
- [x] Sign-in: browser hand-off restored as default + automatic fallback (refresh-token install, cold/warm links, unclaimed links installed); per-provider remote switches `native_google_sign_in` / `native_apple_sign_in` (default off) in onboarding_settings; web drops its own stored copy after hand-off without signing out. Managed Google broker reaches Google's login page (live check); real phone round-trip not yet tested
- [x] Billing: identity requested during RevenueCat configure reconciled in order; failed links retried on resume and stay locked meanwhile
- [x] Billing: purchase approved later by the store now triggers the mandatory account step (persisted marker)
- [x] Sync: learner progress scoped to its account owner in both clients (another account starts clean)
- [x] Startup: store verification no longer bumps learner timestamp; late state load merges without reviving saved Premium and keeps the account step; analytics setup bounded to 2 s
- [x] Player: queued pause cleared on re-activation/ready replay in both clients (new failing-first web test); founder decoder released and awaited before trial
- [x] Emulator E2E fixture keeps the simulated entitlement and accepts founder screen on or off
- [x] searchClips empty filters identical in both clients (parity tests)
- [x] Local checks: Flutter analyze clean, 155 Flutter tests, 143 web tests, typecheck, preview build OK
- [x] iOS App Store profile regenerated with Sign in with Apple (old one was INVALID); GitHub secret updated
- [x] Emulator E2E found + fixed: first-launch analytics question rendered with fallback text style (yellow underline) — now its own Material layer; E2E answers it, uses the store stand-in (emulator has no Play billing), profile-name stand-in
- [x] Web published: live /account bridge shows Google only (no email/Lovable) and auto-starts Google login (checked on the live site)
- [x] Split APK measured: arm64-v8a 54.89 MB, armeabi-v7a 52.56 MB (old universal 93.34 MB)
- [x] GitHub emulator E2E green (run 40126680392): 48 screenshots, onboarding→founder→trial→account→feed→word→Ask→review→14-step tour→feed swipes, 0.00px wobble, no crash/ANR lines. Emulator cannot play YouTube (stays 0:00, same as the old green run)
- [x] Store release run 40126691869 green: Play internal 1.2.0 (112) completed; TestFlight 1.2.0 (112) VALID, in beta testing for the Kizuki team group (new signing profile worked)
- [ ] Real-phone check on build 112 (needs the user's phone): Google sign-in round-trip back into the app, fast swiping, video playback, purchase → account step
- [ ] Native Google/Apple account sheets: switches stay off until the app's own Google/Apple IDs are accepted by the sign-in backend (needs the Google web client secret + Apple settings from the user); browser hand-off is used meanwhile

## App size + welcome tour polish (24 Oct)
- [x] Remote founder screen: public read-only onboarding_settings row, no client writes, default ON, cached offline choice; Flutter first mirrored web checks startup, plan Continue and direct founder entry. Live OFF skips to trial and live ON restores video; tested both and restored ON. 79 tests pass, preview build OK. No app publication or native build performed; installed old apps need the new build once before this flag works.
- [x] Trial preparation starts at launch/plan/founder: shared content + first starter note/poster, YouTube API bootstrap (native DNS/TLS only, not guaranteed shared WebView cache). Browser verified resource requests before trial, 0 YouTube surfaces on founder / 1 in trial. Actual YouTube video buffering is still controlled by YouTube; no downloaded or hidden-playing clip, native speed improvement not measured.
- [x] Follow-up junk audit: 0 orphan explanations, 0 unreferenced dictionary entries; all 8 mascot poses, 8 font files and founder video/poster used. Removed unused cupertino_icons dependency/font (old APK font 533 compressed bytes) and compacted 2,562 note exports, excluding build-only signatures while keeping source validation. 624,043 bundled bytes removed per client (~86,199 compressed bytes estimated versus old APK). All notes compared field-by-field and both clients identical; 13 tests pass and actual word explanation renders with no errors. No massive unused asset payload found; native dependency resolution/build remains pending in CI.
- [x] Existing signed universal APK measured: 93.34 MB; 59.98 MB is three ABI runtimes. CI now produces separately signed arm64-v8a / armeabi-v7a / x86_64 APKs, with size reports and x86_64 emulator selection; Play AAB unchanged, R8 remains off. Removing other two runtimes predicts ~39.71 MB saved for arm64, not a measured new APK. All content/video/fonts/features retained.
- [x] Flutter first, mirrored web: video/speed/save/display introduction restored, labelled contextual Ask example without sending a question, compact tips above shorter scrollable tour sheets; normal sheets unchanged. Native integration walkthrough updated including existing missing kana step.
- [x] Web walkthrough: all 14 steps at 384×624, 360×640, 412×880 (42 screenshots inspected), returns to feed, zero tutor requests and page errors; 86 targeted web tests + size-report test pass, preview build OK. Subscription simulated only for UI checks; no authenticated tutor claim.
- [ ] New signed APK size + Flutter analyze/tests/emulator validation: Flutter SDK unavailable locally; requires next GitHub Actions run. No store release/publication requested or performed.

## PostHog product analytics (24 Oct)
- [x] Manual public-token install with verified US project host; Flutter first, mirrored web: ~50 named events covering screens/dwell, tabs/controls, onboarding/tour steps, paywall/checkout/restore results, account identity, clips/playback, words, reviews, Ask outcomes and settings. Official SDKs; no Meta event duplication.
- [x] Explicit analytics choice before SDK starts, equal accept/reject, Settings withdrawal, local time/notice-version evidence preserving prior acceptance; web honors other-tab withdrawal. Credentials, OAuth URLs, chat/support text, notes and receipts excluded; replay disabled; shared legal text regenerated.
- [x] 132 web tests pass; preview build OK. Browser verified zero PostHog requests before acceptance and after withdrawal, onboarding progression and no page errors. Test-only bot-filter bypass allowed one marked test event to receive PostHog HTTP 200; automated browser filtering remains enabled in app code. Navigation aborted another in-flight test request; provider receipt does not establish dashboard funnels.
- [ ] Native analyze/tests and real authenticated identity/checkout flow: Flutter SDK and an app/store test account unavailable here; native consent tests added but not run. No publication or store upload requested in this task.
- [ ] Saved PostHog dashboard/funnels and project retention: public ingest token cannot administer dashboards or read analytics; needs PostHog account access. Funnel definitions saved in docs/posthog-tracking.md.

## Social-only sign-in: Google + Apple (24 Oct, user request)
- [x] Native SDK wiring authored with user's Google Web/iOS IDs, Google authentication/access-token exchange, Apple hashed/raw nonce exchange, iOS URL scheme and Apple entitlement. Android Google only; iOS Google+Apple; icons, busy/error states, no Lovable button. Flutter first, mirrored web platform preview; two rule tests pass (65 logic tests total). Screenshots are actual web phone preview, not native captures.
- [x] Apple Developer: enabled APPLE_ID_AUTH for com.kizukijapan.app with PRIMARY_APP_CONSENT and read back the capability successfully. Existing App Store Connect key is usable for this operation; this is not a Sign in with Apple private key. No phone login behavior changed yet.
- [ ] Configure own provider backend audiences: user's three Google client IDs are saved and native Google uses Web ID as serverClientId, but no offered tool sets BYOC audiences. User must configure Google own credentials in Cloud Auth settings; Apple allowed ID must include com.kizukijapan.app. Google Web secret and Apple own auth settings not supplied/configured. Do not run configure_social_auth to overwrite them with managed credentials. Play SHA-1 obtained from Play API-generated build 111, separate APK signing SHA-1 obtained from GitHub release; client registration association unverified.
- [x] Email/password sign-up, password field, forgot-password and email-confirmation screens removed from both clients; `/reset-password` web route deleted; email provider disabled in the backend (Google, Apple, Lovable enabled via managed social login — Apple newly enabled).
- [x] Flutter first: account screen now shows Continue with Apple / Google / Lovable; sign-in opens the published web origin (`/account?bridge=1&provider=…`) in the system browser; on completion the web page hands the session back via `kizuki://auth?session=…` (intent URL on Chrome Android), restored with `auth.recoverSession` (app_links added; Android intent-filter + iOS CFBundleURLTypes registered). Waiting/cancel/offline states + "Open browser again" for when the browser round-trip is lost.
- [x] Web mirrored: bridge mode on /account auto-starts the chosen provider, returns to the same page after OAuth, and redirects to the deep link; non-bridge flow unchanged for the preview.
- [x] 127 web tests pass. AGENTS.md rule added for the shared hand-off flow.
- [ ] Native analyze/tests/dependency locks + real Google/Apple account round-trip: Flutter SDK unavailable here; next CI native build needed. Existing iOS provisioning profile must be regenerated with Apple sign-in capability. No upload/publication performed; native login not verified or ready.

## Subscription expiry access (24 Oct)
- [x] Flutter first then web: central learning gate, expiry dates, no legacy free clips/questions or seen-clip bypass; native startup requires store verification, refreshes on resume, expiry timer closes sheets, renewed paid dates keep access. Purchase/restore/account/settings/help remain accessible; saved progress retained.
- [x] Ask checks the authenticated user's live RevenueCat Premium entitlement server-side; native login links the store identity to the same account. 127 web tests pass, mirrored native rule tests added; phone-size browser checks eight blocked paths, no player, settings reachable, renewal access and auto-lock while open, no page errors.
- [ ] Native tests + real store trial-to-expiry/renewal/restore check: Flutter SDK unavailable here; next native CI build and actual store account needed. No new Play/TestFlight build uploaded or web publication in this task.
- [ ] Authenticated tutor end-to-end check: requesting user has no matching app account/session; server predicate tested, live RevenueCat project/entitlement read verified, but signed-in request not exercised.

## Tutor model: can a basic model do it? (24 Oct, user question)
- [x] Ran 8 real tutor questions (greeting meaning, は vs が, て-form vs ます-form, 〜といいな, alternate kanji reading, a mis-heard transcript たへた, an off-topic jailbreak, polite-form + readings) through the exact Kizuki instructions on 6 gateway models. Nothing in the app changed.
- [x] Cost per question (measured tokens × catalog price): gpt-6-luna 0.00038 credits, gpt-5.6-luna 0.00068, gemini-3.1-flash-lite 0.0014, gpt-6-sol 0.0071, gpt-6-astra (current) 0.036 — the cheapest current model is ~96× cheaper and ~2× faster (1.9s vs 4.0s).
- [x] Quality: cheap models got all 8 right, caught the transcript mis-hear and refused the off-topic ask. Astra still edges them on spotting a wrong gloss in the clip's own metadata (いってらっしゃい ≠ "welcome back") and on completeness (2 alternate readings vs 1).
- [x] gemini-3.8-flash cut its answer off mid-sentence at the same output cap and was slower and costlier than gpt-6-sol; claude-haiku-4-5 returned 400 on this endpoint (needs its native endpoint) — not fairly compared.
- [ ] Pick the tutor model: keep astra, move to luna, or hybrid (cheap model on word taps, astra on the Explain tab) — waiting on the user.

## Word card meanings + tutor model (24 Oct, user question)
- [x] Word card keeps showing the clip meaning first plus all dictionary senses — user decided "aise hi sahi hai", no change made.
- [x] Ask Kizuki's active model checked (not changed): `openai/gpt-6-astra` through the Lovable AI Gateway, low reasoning effort, answers not stored; both clients hit the same server route so both get the same tutor.


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
- [x] Account screen is social-only (Apple / Google / Lovable via browser hand-off — see Social-only sign-in, 24 Oct); email/password flow removed

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
