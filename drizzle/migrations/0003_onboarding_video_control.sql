CREATE TABLE public.onboarding_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  founder_video_enabled boolean NOT NULL DEFAULT true
);
GRANT SELECT ON public.onboarding_settings TO anon, authenticated;
GRANT ALL ON public.onboarding_settings TO service_role;
ALTER TABLE public.onboarding_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public onboarding presentation settings" ON public.onboarding_settings FOR SELECT TO anon, authenticated USING (id = 1);