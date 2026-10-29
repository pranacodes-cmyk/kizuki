-- Language pack pointer on the project-owned backend (applied through the Management API by
-- scripts/i18n/publish_locale_packs.ts --setup). Additive and idempotent.
-- locale_packs = {"vi": {"v": 3, "urls": ["https://<r2>/locale/vi/v3.json", "https://<backend>/…/locale/vi/v3.json"]}, …}
-- An empty object (default) or a missing language means: no pack, the app shows English content.
alter table public.content_settings add column if not exists locale_packs jsonb not null default '{}'::jsonb;
grant select (locale_packs) on public.content_settings to anon, authenticated;
