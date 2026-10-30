# Migration: Lovable Cloud → External Supabase (gcoboyhfhadivheoilxp)

## Requested Android + iOS release — 2026-10-30
- [x] Snapshot latest source on release/20261030-1793330003; dispatch both store targets and Android emulator checks.
- [x] Android 1.2.0 (129) uploaded; Google Play internal read-back confirms versionCodes [129], status completed. Flutter checks pass.
- [ ] iOS upload requested again: fresh distribution certificate and matching app/widget profiles verified with assigned App Group; encrypted GitHub signing secrets replaced. Exact bundle-ID filtering corrected; dispatch and Apple upload read-back pending.
- [ ] Android emulator verification blocked: run 40996153758 times out waiting for welcome screen (same failure as previous build). App-flow test needs first-run language-picker investigation; build 129 is internal only, not production.

## Five learner languages (vi, id, th, ko, pt-BR) + R2 language packs — 2026-10-29
- [x] R2 bucket `kizuki-packs` created (free tier), public r2.dev URL + CORS + API upload verified.
- [x] Translation pipeline scripts/i18n/translate_content.py (deterministic checks + independent review); durable store scripts/i18n/store_content.py → scripts/i18n/content/<lang>/ (gz, restorable).
- [x] Mirrored language rules + tests (picker list, phone-locale suggestion, highlightParts).
- [x] Interface text wrapped in tr()/trn() in both clients (paywall, Ask Kizuki copy, support FAQ/deletion copy, widget date, tabs included).
- [x] UI catalog: 782 strings × 5 languages; translate (gpt-6-astra) → checks → review (gemini-3.1-pro) → proofread (claude-opus-5-5) → overrides.json; i18n-strings.json + strings.g.dart; parity tests in both clients.
- [x] Fonts: Nunito subset with Vietnamese glyphs (Flutter); Noto Thai/Korean/emoji on web.
- [x] Ask Kizuki answers in the app language (lang in body; older apps keep English). Needs a web Publish to reach phones.
- [x] Content translation + independent review finished (2,516 credits total incl. interface, under the 2,600 limit). Clips per language: vi 2,562/2,562 · pt 2,561 · id 2,553 · th 2,494 · ko 2,440; dictionary 7,991–8,003/8,003 and all 3,680 grammar lines. The rest stay English (failed checks, mostly long clips/names).
- [x] Locale pack format + mirrored rules/tests (pointer, manifest, fingerprint, overlay apply: logic 103/103 both clients).
- [x] Builder scripts/i18n/build_locale_packs.py (ships only reviewed translations) + uploader scripts/i18n/publish_locale_packs.ts (backend storage + R2 mirrors, read-back, pointer). Dry run: all 5 packs pass every check.
- [x] Bundled starter overlays (starter clips + their words + grammar + notes) in public/data/locale + mobile/assets/data/locale. Rebuild after dictionary review (builder now requires reviewed dictionary/grammar).
- [x] Clients: language pack download (trial/Premium + language ≠ English), two mirrors, per-file sha/size check + full parse check + re-check on read, resume, backoff 5 s→30 min, next-start activation, English fallback. Flutter locale_pack_test 7/7; web verified in preview (vi starter clip title/subtitles + word card in Vietnamese).
- [x] Packs live for all 5 languages (vi v2 — v1 was the unreviewed test; id/th/ko/pt v1) on backend storage + R2. Verified: web preview downloads/activates Korean live and shows a non-starter clip in Korean after reload; Thai via R2 with backend blocked; no download without trial/Premium; Flutter code path downloads, verifies and re-checks all 5 live packs.
- [x] Saved words show their meaning in the current app language (mirrored savedGloss; older saves count as English). Meaning comparison now works for Thai/Korean/Vietnamese letters (repeatsSense).
- [x] Settings → App language shows "Translations downloaded / Downloading… / First clips translated" (both clients; web verified in vi).
- [x] Language picker + Settings row verified in preview (phone locale ko → Korean preselected; picker heading/explanation were untranslated → fixed in both clients). Feed checked in vi/id/th/ko/pt; Vietnamese crawl of 20 screens finds no untranslated interface text (fixed: study-window labels on web, review-done note in both). Privacy/Terms stay English by design.
- [x] Widgets/explanations follow a language switch (Flutter widget word cache + open clip's explanations now refresh; web remounts). Reminder text uses tr() (device check pending with the next build).
- [x] Verified locally: flutter analyze clean, 215 Flutter tests, 198 web tests, typecheck clean.
- [ ] CI release build with the 5 languages: waiting for the user's OK to send a new Android build; iOS still waits on the App Group. Web preview already has them; the public website needs Publish → Update.
- [ ] BLOCKED on user: custom domain on Cloudflare for R2 (no zone on the connected account; r2.dev is rate-limited). Store listings per language. Native-speaker spot review before paid campaigns.

## Native learning widgets — 2026-10-29
- [x] Download public Moji Reel DbqerGJJ4Kb (9.07 s), save reference in Files and inspect frames: iPhone rectangular lock-screen kanji, reading, meaning and example; sequence shows different words/times. No native widget support currently exists in Kizuki.
- [x] Implement Android providers, iOS WidgetKit target/App Group bridge, Flutter widget settings and matching web simulation (small/wide/large/lock), opt-in saved learning words and two-hour rotation. Native compilation is not yet verified.
- [x] Web preview flow: all four sizes, persisted reading toggle, Android instructions and 360/430px checks; zero browser errors. 103 logic/content tests and 4 signing safety tests pass; build OK. Dart syntax/XML/plists parse; duplicate Xcode ID regex matches include nested target attributes, not evidence of duplicate objects.
- [ ] Native analyze/tests and Android widget emulator/install/tap checks: local Flutter SDK Dart 3.10.1 is older than project's required ^3.13.5. Run required pinned SDK in GitHub checks before release; no native build dispatched this turn.
- [ ] iOS signing blocked: App IDs registered + App Groups capability enabled on both via API (29 Oct). Waiting on user to create group.com.kizukijapan.app.widgets in Apple Developer and assign it to both IDs; then dispatch iOS release.
- [x] Android build 127 with widgets uploaded to Play internal track (CI analyze/test passed).

## Workspace transfer check + Meta video ads — 2026-10-28
- [ ] Android campaign launch requested: live KILVIS read confirms existing Kizuki campaign PAUSED, ₹1,500/day, zero ad sets and zero ads. Android Play association verified. BLOCKED: documented Lovable creation flow supports website ads only; Android Start Trial eligibility/receipt and creator footage rights remain unverified. Do not activate the empty shell or substitute website/installs ads.
- [x] Backend after transfer: external project healthy; preview login, learner progress, profiles and Ask Kizuki answer.
- [x] Live Ask Kizuki diagnosed: published worker gets AI Gateway 403 Forbidden (preview with same code answers) → live deployment still carries pre-transfer AI access; republish needed.
- [ ] BLOCKED on user: click Publish → Update, then re-test live Ask Kizuki (phones call the live site for Ask).
- [x] 4 Meta Reels/Stories video ads (9:16, 14–16 s, 1080×1920, −14 LUFS): doomscroll, textbook, commute, coffee. Generated hook + real app recording + captions + music + end card; captions kept inside the 4:5 feed crop. Files collection "Kizuki Meta video ads".
- [ ] BLOCKED on user decision: app footage inside the ads shows third-party YouTube creators' videos (beach vlogger, goat video, two cartoons). Before paid spend: get those creators' OK, or re-record the app segments on clips we have rights to.
- [ ] Optional, needs user's business-name confirmation: brand profile in Files (marketing/brand_profile.html).


## Apple submission preparation — 2026-10-26
- [x] Final live iOS check: build 124 VALID/selected, version READY_FOR_REVIEW, 6 draft items (version + group + 4 subscriptions), 12 screenshots COMPLETE, both locales' own-domain links, review contact/credentials present; backend review switch ON, password authentication 200, RevenueCat Premium through 2030 and all four iOS offering products verified; 91 logic/legal tests + iOS attribution test pass.
- [x] User confirmed TestFlight 124 login/playback/restore/ATT checks and App Privacy Publish. Submitted existing 6-item iOS draft at 2026-10-26T13:16:02Z; API read-back confirms submission, version 1.2.0/build 124 and all four subscriptions WAITING_FOR_REVIEW. Native device checks are user-confirmed, not sandbox-observed. Web reviewer sign-in reaches /feed but prototype's simulated Premium blocks learning; this is not evidence of native entitlement failure.
- [x] Correct Apple review instructions and false free-tier claim; verify 1,822-character notes, sign-in required, preserved contact/credentials and one attachment. No submission made.
- [x] Verify selected build 123 and both subscriptions READY_TO_SUBMIT; Kizuki 1.2.0 remains PREPARE_FOR_SUBMISSION. Do not treat account-wide review draft items as Kizuki submission.
- [x] Release snapshot includes 14 latest source files; iOS-only GitHub run 40325879272 passed Flutter analyze/tests and IPA upload. Apple build 124 VALID, selected on 1.2.0; Android skipped, no review submission.
- [x] User confirmed TestFlight build 124 reviewer login, ATT, playback and restore checks before submission.
- [ ] Finalize App Privacy/Meta attribution, subscription inclusion, country availability and agreements/tax/banking. Live attribution access missing; Apple availability/price reads do not confirm configuration, account agreements require account-side verification.

## Standalone Kizuki public website — 2026-10-26
- [x] Generate branded marketing, support, privacy, terms and deletion HTML pages for pranacodes.in from existing approved copy; no app or store URL changes before hosting.
- [x] Check all five pages on mobile/desktop (10 checks), legal parity (2 tests), FAQ/email actions and local links; inspect ZIP and provide intended URLs. Files mount temporarily unavailable; download served through project preview instead.
- [x] Verify user-hosted marketing, support, privacy and account-deletion pages on pranacodes.in.
- [x] Update mirrored in-app legal links and store source; six legal tests pass; runtime API/auth origins unchanged.
- [x] Update Apple en-US/es-MX privacy, support, marketing and description privacy URLs; read back all values; artwork unchanged.
- [ ] Google Play live URL update: API rejects saving without automatic review submission; edit discarded, needs authorization to send listing changes for review. Privacy and deletion form fields need Play Console manual update.
- [ ] Replace Terms URL only after user supplies its hosted replacement; existing Terms remains working fallback.

## iOS Meta audit and hosted deletion page — 2026-10-26
- [x] Read https://pranacodes.in/kizuki-delete-account: app/developer identity, deletion instructions, retained data and subscriptions are visible; developer spelling needs exact listing match.
- [x] Inspect iOS Meta initialization, ATT, SKAdNetwork and six app-side event mappings; default advertiser-ID collection off before runtime ATT decision.
- [ ] Verify installed iOS release ATT states and Meta event receipt, plus RevenueCat Meta integration and SKAdNetwork postbacks. Blocked on live account/device evidence; no Meta/RevenueCat account connection or iOS runtime available here.

## Review login paywall regression — 2026-10-26
- [x] Wait for account-specific RevenueCat verification before finishing native sign-in; keep verified Premium through learner sync.
- [x] Skip acquisition onboarding/paywall for active Premium accounts in both clients; add regression tests and verify review login.
- [x] Build 122 passed phone checks and uploaded to Google Play internal + TestFlight.
- [x] Paywall "I already have an account" link (review switch only) in Flutter + web; web path paywall → email login → Feed verified.
- [ ] Install build 122 and verify review email login on a real phone. Waiting for user device check.

## Legal policy update — 2026-10-26
- [x] Update Kizuki Privacy and Terms using Kiku-like structure but verified Kizuki practices; keep the paywall unchanged.
- [x] Generate matching phone copy, run legal parity tests (2 pass), verify updated local pages and support access; no browser errors, build OK.
- [ ] Publish revised web policies and include revised in-app copy in a future phone release. Waiting for explicit publish/release authorization; public website still serves earlier copy.

## ASO (App Store + Google Play search) — 2026-10-25
- [x] Research 80 searches on US App Store order + suggestions, US/India Google Play top 10 + installs, competitor titles/subtitles/ratings.
- [x] Rewrite store/listing.json (en-US + es-MX App Store sets, Play title/short/full); remove false free-tier claim and wrong clip/video counts; original copy, no competitor names.
- [x] Add scripts/stores/check_listing.py (limits, repeats, brands, free-tier, Play title rules) and run it before every push.
- [x] Deliver keyword spreadsheet + Hinglish ASO playbook PDF in Files (/mnt/documents/aso).
- [ ] Fix rating prompt in both clients: remove custom stars question, call native review prompt directly after 2 good sessions (Google in-app review rule + Apple 5.6.1). Waiting for user OK.
- [x] App Store 1.2.0 draft: new en-US + es-MX text and approved screenshots are saved (sent by an accidental run on 25 Oct; not submitted, not public). push_listing.py now refuses --help/unknown args.
- [x] New listing text pushed to Google Play + App Store 1.2.0 (read back 25 Oct; screenshots kept).
- [x] Save approved own-domain Privacy/Support/Marketing/Deletion URLs and update both Apple locales; remaining Play/Terms steps tracked above.
- [ ] Re-check rankings 2–4 weeks after public launch; swap non-ranking keywords. Needs the apps to be public.


## Approved store screenshots — 2026-10-25
- [x] Correct headline clip-count claim to 2,500+ and remove invented exterior video cards; prepare six approved images per store.
- [x] Upload screenshots only to Google Play and editable App Store version 1.2.0, without changing app binaries or other listing fields.
- [x] Read back six Google Play screenshots after commit; all six Apple screenshot assets COMPLETE. Apple version not submitted for review.

## Requested store release — 2026-10-25
- [x] Run current web tests and inspect release preflight (164 tests pass; unused Flutter variable removed).
- [x] Sync latest phone changes to GitHub and dispatch Android + iOS release (466fb0f; store run 40206636934, emulator run 40206637388).
- [x] Verify Flutter checks and Android emulator E2E (both success).
- [x] Confirm Google Play internal and App Store Connect/TestFlight uploads (1.2.0 build 117; Apple VALID; not public review).

## Reported phone regressions — 2026-10-25
- [x] Fix Android system Back across onboarding; dispatcher + PopScope with dialog-first handling and empty-stack fallback. GitHub run 40212332534: Flutter analyze + 179 tests pass; emulator question-Back and trial-root-Back pass before video failure. Not uploaded to stores.
- [x] Remove redundant initial seek and poster-over-player transition in Flutter, then mirror web; native startup improvement still needs visual verification.
- [x] Fix welcome tour card/Skip overlap and clipped copy in Flutter, then mirror web (384×624 and 402×874 web screenshots inspected).
- [x] Run 164 web tests, Flutter analyze/tests and emulator flow; inspect native kana screenshot (clean) and trial screenshots (still buffering despite passing E2E).
- [ ] Fix/verify native video first-frame timing (now: blank WebView warms engine + caches YouTube base.js at app start; needs phone check): strict playback assertion now fails run 40212332534 (player reaches buffering, never advances in 25s; black native screenshot). Root cause beyond player buffering remains unproven; do not ship as fixed. Early warming fetches data/bootstrap, not decoded YouTube frames.

- [x] Verify external project access via Management API (token EXT_SB_ACCESS_TOKEN)
- [x] Dump current schema: tables, RLS policies, triggers, functions
- [x] Recreate schema + RLS + triggers on external project (REST live-test 200)
- [x] Configure auth on external: Google (3 client IDs + secret), Apple (bundle ID), redirects
- [x] Rewire web app code (src/lib/backend.ts + backend-config.ts; 146/146 tests pass; typecheck clean)
- [x] Rewire Flutter app config (mobile/lib/services/config.dart)
- [ ] USER STEP: Google Console → Web client (lp23…) → Authorized redirect URIs → add https://gcoboyhfhadivheoilxp.supabase.co/auth/v1/callback (website Google login)
- [ ] OPTIONAL: Apple Services ID + return URL for website Apple login (phone native Apple works without it)
- [ ] Publish web app (Ask route must verify against external BEFORE new APK ships)
- [ ] GitHub sync + new Android build; device test: Google + Apple native login, sync, Ask
- [ ] LAST (irreversible): user removes Lovable Cloud via More → Database → Manage → Settings → Remove Database
- [ ] Note: old 4 test accounts don't carry over; fresh sign-in on new backend

## Play Console "Sign in details" declaration - 2026-10-26
- [x] Found Google's rule for standard Google sign-in apps: provide a test Google account's email + password + detailed instructions. No app changes made.

- [x] Test Google account signed in to Kizuki; promotional Premium granted in RevenueCat until 31 Dec 2030.
- [x] Hidden review email sign-in (server switch, currently ON) in Flutter + web; review account review@kizukijapan.com with Premium until 2030; build 121 on Play internal + TestFlight.
- [ ] BLOCKED on user: fill Play Console Sign-in details with the review account, select build 121, send for review; ask to switch the review sign-in OFF after approval.
