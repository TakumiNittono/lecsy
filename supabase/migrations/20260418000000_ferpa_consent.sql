-- B2B minimum-data: FERPA consent tracking
--
-- Why: IEP/ESL directors need evidence that each student actively
-- acknowledged Lecsy's data handling before recording lectures. Required
-- by UF ELI + Santa Fe pilots (see Deepgram/EXECUTION_PLAN.md 2026-06-01).
-- Retention of the timestamp is the artifact; the consent copy itself
-- lives in the iOS FERPAConsentView bundle version log.
--
-- What: one nullable timestamptz per (org_id, user_id) row. null == never
-- consented; non-null == the server-recorded instant the student tapped
-- "Agree & Continue" in the org-scoped consent sheet.

ALTER TABLE public.organization_members
  ADD COLUMN IF NOT EXISTS ferpa_consented_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_org_members_ferpa_consent
  ON public.organization_members (org_id)
  WHERE ferpa_consented_at IS NOT NULL;

-- Users may stamp consent on their own membership row. Existing RLS on
-- organization_members already allows SELECT for the user themselves and
-- UPDATE for admins; we need to grant UPDATE of this one column to the
-- member themselves. Done via a narrow policy rather than widening the
-- existing one.
DO $$ BEGIN
  DROP POLICY IF EXISTS "members_self_consent" ON public.organization_members;
EXCEPTION WHEN undefined_object THEN null; END $$;

CREATE POLICY "members_self_consent"
  ON public.organization_members
  FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
