# Migration: Lovable Cloud → External Supabase (gcoboyhfhadivheoilxp)

## Requested store release — 2026-10-25
- [ ] Run current web tests and inspect release preflight.
- [ ] Sync latest phone changes to GitHub and dispatch Android + iOS release.
- [ ] Verify Flutter checks and Android emulator E2E.
- [ ] Confirm Google Play internal and App Store Connect/TestFlight uploads; distinguish upload from public approval.

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
