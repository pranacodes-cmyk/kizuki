CREATE TABLE public.learner_state (
  user_id uuid PRIMARY KEY,
  state jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.learner_state TO authenticated;
GRANT ALL ON public.learner_state TO service_role;

ALTER TABLE public.learner_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Learners read their own state" ON public.learner_state
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Learners create their own state" ON public.learner_state
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Learners update their own state" ON public.learner_state
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Learners delete their own state" ON public.learner_state
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.touch_learner_state()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER learner_state_touch BEFORE UPDATE ON public.learner_state
  FOR EACH ROW EXECUTE FUNCTION public.touch_learner_state();

-- Lets a signed-in learner permanently delete their own account and data (Play Store requirement).
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not signed in';
  END IF;
  DELETE FROM public.learner_state WHERE user_id = uid;
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;