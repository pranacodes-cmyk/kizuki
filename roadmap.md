# Migration: Lovable Cloud → External Supabase (gcoboyhfhadivheoilxp)

## ASO (App Store + Google Play search) — 2026-10-25
- [x] Research 80 searches on US App Store order + suggestions, US/India Google Play top 10 + installs, competitor titles/subtitles/ratings.
- [x] Rewrite store/listing.json (en-US + es-MX App Store sets, Play title/short/full); remove false free-tier claim and wrong clip/video counts; original copy, no competitor names.
- [x] Add scripts/stores/check_listing.py (limits, repeats, brands, free-tier, Play title rules) and run it before every push.
- [x] Deliver keyword spreadsheet + Hinglish ASO playbook PDF in Files (/mnt/documents/aso).
- [ ] Fix rating prompt in both clients: remove custom stars question, call native review prompt directly after 2 good sessions (Google in-app review rule + Apple 5.6.1). Waiting for user OK.
- [x] App Store 1.2.0 draft: new en-US + es-MX text and approved screenshots are saved (sent by an accidental run on 25 Oct; not submitted, not public). push_listing.py now refuses --help/unknown args.
- [x] New listing text pushed to Google Play + App Store 1.2.0 (read back 25 Oct; screenshots kept).
- [ ] Own domain for Privacy/Terms/Support links (current URL contains a competitor name). Needs user to buy/connect a domain.
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
