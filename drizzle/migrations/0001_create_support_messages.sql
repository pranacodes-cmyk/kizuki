CREATE TABLE public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid NULL,
  email text NOT NULL CHECK (char_length(email) BETWEEN 3 AND 255 AND email LIKE '%@%'),
  topic text NOT NULL DEFAULT 'other' CHECK (topic IN ('subscription', 'account', 'bug', 'content', 'feedback', 'other')),
  message text NOT NULL CHECK (char_length(message) BETWEEN 5 AND 2000),
  platform text NOT NULL DEFAULT 'web' CHECK (platform IN ('web', 'android', 'ios')),
  app_version text NULL CHECK (app_version IS NULL OR char_length(app_version) <= 40)
);

GRANT INSERT ON public.support_messages TO anon;
GRANT INSERT ON public.support_messages TO authenticated;
GRANT ALL ON public.support_messages TO service_role;

ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can send a support message"
ON public.support_messages
FOR INSERT
TO anon
WITH CHECK (user_id IS NULL);

CREATE POLICY "Signed-in users send support messages as themselves"
ON public.support_messages
FOR INSERT
TO authenticated
WITH CHECK (user_id IS NULL OR user_id = auth.uid());