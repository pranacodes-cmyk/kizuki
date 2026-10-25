# Migration: Lovable Cloud → External Supabase (gcoboyhfhadivheoilxp)

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
- [ ] USER STEP: Google Console → Web client (lp23…) → Authorized redirect URIs → add https://gcoboboyhfhadivheoilxp.supabase.co/auth/v1/callback (website Google login)
- [ ] OPTIONAL: Apple Services ID + return URL for website Apple login (phone native Apple works without it)
- [ ] Publish web app (Ask route must verify against external BEFORE new APK ships)
- [ ] GitHub sync + new Android build; device test: Google + Apple native login, sync, Ask
- [ ] LAST (irreversible): user removes Lovable Cloud via More → Database → Manage → Settings → Remove Database
- [ ] Note: old 4 test accounts don't carry over; fresh sign-in on new backend
