-- DB hardening pass: indexes, constraints, dedupe, cascades.
-- Goal: bring transcripts/summaries/usage_logs to production-grade hygiene
-- without breaking existing flows. Safe to re-run (all guarded with IF EXISTS / IF NOT EXISTS).
--
-- What this migration does NOT do (intentional, deferred):
--   * RLS policies — already enabled, don't want to risk breaking edge functions
--     that use service role until each policy is tested.
--   * CHECK (length(content) > 0) — would block any pre-existing empty rows.
--   * Soft-delete column — will add later when we have a "Trash" UI.
--   * pg_cron cleanup — needs separate enablement.
--   * Full-text search index — defer until search is actually wired up.

-- ============================================================
-- 1. Dedupe NULL client_id rows
-- Keep the row that has client_id (= came from new iOS client),
-- delete the older NULL one when (user_id, title, created_at) collide.
-- ============================================================
DELETE FROM transcripts a
USING transcripts b
WHERE a.user_id = b.user_id
  AND a.title = b.title
  AND a.created_at = b.created_at
  AND a.client_id IS NULL
  AND b.client_id IS NOT NULL
  AND a.id <> b.id;

-- ============================================================
-- 2. Indexes for the queries we actually run
-- ============================================================
CREATE INDEX IF NOT EXISTS transcripts_user_created_idx
  ON transcripts (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS transcripts_org_created_idx
  ON transcripts (organization_id, created_at DESC)
  WHERE organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS summaries_transcript_idx
  ON summaries (transcript_id);

CREATE INDEX IF NOT EXISTS summaries_user_created_idx
  ON summaries (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS usage_logs_user_created_idx
  ON usage_logs (user_id, created_at DESC);

-- ============================================================
-- 3. updated_at column + trigger on transcripts
-- ============================================================
ALTER TABLE transcripts
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS transcripts_set_updated_at ON transcripts;
CREATE TRIGGER transcripts_set_updated_at
  BEFORE UPDATE ON transcripts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 4. ON DELETE CASCADE for user_id foreign keys
-- When a Supabase auth user is deleted, their transcripts /
-- summaries / usage_logs should also be deleted automatically
-- (Apple "delete account" + GDPR right-to-erasure compliance).
-- ============================================================
DO $$
DECLARE
  con record;
BEGIN
  -- transcripts.user_id
  FOR con IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.transcripts'::regclass
      AND contype = 'f'
      AND conname ILIKE '%user_id%'
  LOOP
    EXECUTE format('ALTER TABLE public.transcripts DROP CONSTRAINT %I', con.conname);
  END LOOP;
  ALTER TABLE public.transcripts
    ADD CONSTRAINT transcripts_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

  -- summaries.user_id
  FOR con IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.summaries'::regclass
      AND contype = 'f'
      AND conname ILIKE '%user_id%'
  LOOP
    EXECUTE format('ALTER TABLE public.summaries DROP CONSTRAINT %I', con.conname);
  END LOOP;
  ALTER TABLE public.summaries
    ADD CONSTRAINT summaries_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

  -- summaries.transcript_id
  FOR con IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.summaries'::regclass
      AND contype = 'f'
      AND conname ILIKE '%transcript_id%'
  LOOP
    EXECUTE format('ALTER TABLE public.summaries DROP CONSTRAINT %I', con.conname);
  END LOOP;
  ALTER TABLE public.summaries
    ADD CONSTRAINT summaries_transcript_id_fkey
    FOREIGN KEY (transcript_id) REFERENCES public.transcripts(id) ON DELETE CASCADE;

  -- usage_logs.user_id
  FOR con IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.usage_logs'::regclass
      AND contype = 'f'
      AND conname ILIKE '%user_id%'
  LOOP
    EXECUTE format('ALTER TABLE public.usage_logs DROP CONSTRAINT %I', con.conname);
  END LOOP;
  ALTER TABLE public.usage_logs
    ADD CONSTRAINT usage_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
END$$;

-- ============================================================
-- 5. NOT NULL guards on critical columns
-- Skip if existing data violates — fail loudly so we know.
-- ============================================================
ALTER TABLE transcripts ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE summaries ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE summaries ALTER COLUMN transcript_id SET NOT NULL;
ALTER TABLE usage_logs ALTER COLUMN user_id SET NOT NULL;

-- ============================================================
-- 6. CHECK constraints on transcripts
-- Visibility must be one of the allowed values; duration sane.
-- ============================================================
ALTER TABLE transcripts
  DROP CONSTRAINT IF EXISTS transcripts_visibility_check;
ALTER TABLE transcripts
  ADD CONSTRAINT transcripts_visibility_check
  CHECK (visibility IS NULL OR visibility IN ('private', 'org_wide'));

ALTER TABLE transcripts
  DROP CONSTRAINT IF EXISTS transcripts_duration_check;
ALTER TABLE transcripts
  ADD CONSTRAINT transcripts_duration_check
  CHECK (duration IS NULL OR duration >= 0);
