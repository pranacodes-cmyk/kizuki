CREATE TABLE public.app_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid NULL,
  platform text NOT NULL CHECK (platform IN ('web', 'android', 'ios')),
  app_version text NULL CHECK (app_version IS NULL OR char_length(app_version) <= 40),
  route text NULL CHECK (route IS NULL OR char_length(route) <= 120),
  kind text NOT NULL CHECK (char_length(kind) <= 40),
  message text NOT NULL CHECK (char_length(message) <= 600),
  stack text NULL CHECK (stack IS NULL OR char_length(stack) <= 3000)
);

GRANT INSERT ON public.app_errors TO anon;
GRANT INSERT ON public.app_errors TO authenticated;
GRANT ALL ON public.app_errors TO service_role;

ALTER TABLE public.app_errors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can report an app error"
ON public.app_errors FOR INSERT TO anon WITH CHECK (user_id IS NULL);

CREATE POLICY "Signed-in users report errors as themselves"
ON public.app_errors FOR INSERT TO authenticated WITH CHECK (user_id IS NULL OR user_id = auth.uid());
