ALTER TABLE public.onboarding_settings
  ADD COLUMN IF NOT EXISTS native_google_sign_in boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS native_apple_sign_in boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.onboarding_settings.native_google_sign_in IS 'Phone apps use the native Google account sheet only after the backend accepts the app''s own Google client audience; otherwise they use the browser hand-off.';
COMMENT ON COLUMN public.onboarding_settings.native_apple_sign_in IS 'iPhone app uses native Sign in with Apple only after the backend accepts the bundle ID audience; otherwise it uses the browser hand-off.';