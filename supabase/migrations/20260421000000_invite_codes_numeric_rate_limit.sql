-- Switch invite codes to 6-digit numeric and add a per-user rate limit
-- (10 attempts / 1 minute) on redeem_invite_code.
--
-- Why numeric:
--   FMCC / Santa Fe ESL students type on mobile numeric keypads. The
--   letters↔numbers toggle in iOS / Android keyboards was a non-trivial
--   typo source in Kim's in-class dry runs. Numeric also makes printed
--   cards read out loud cleanly ("two-four-zero-nine-one-seven").
--
-- Entropy tradeoff:
--   6-digit numeric gives 10^6 = 1M combos vs 32^6 ≈ 1B for the old
--   alphanumeric scheme. Compensated by:
--     (a) 10 attempts/min rate limit below
--     (b) Supabase's built-in per-IP cap on signInAnonymously (~30/hr)
--     (c) only ~30-100 codes active per org at once, so collision rate
--         for a blind guess is ~1 in 10k-30k per attempt
--
-- Old alphanumeric rows (if any) in organization_invite_codes still
-- validate through the unchanged normalization (upper + strip); only
-- the UI keypad prevents users from typing them. Regenerate test codes
-- via generate_invite_codes() after this migration applies.

-- 1) Per-user attempt log (feeds the rate limiter).
-- RLS is enabled with no policies, so only SECURITY DEFINER functions
-- can read / write. We never return attempt rows to clients.
CREATE TABLE IF NOT EXISTS public.invite_redeem_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  attempted_code text,
  success boolean NOT NULL,
  attempted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_redeem_attempts_user_time
  ON public.invite_redeem_attempts (user_id, attempted_at DESC);

ALTER TABLE public.invite_redeem_attempts ENABLE ROW LEVEL SECURITY;

-- 2) Redeem RPC with rate limiting.
CREATE OR REPLACE FUNCTION public.redeem_invite_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_code       public.organization_invite_codes;
  v_user       uuid := auth.uid();
  v_existing   public.organization_members;
  v_normalized text;
  v_recent_attempts int;
  v_rate_limit_window  constant interval := '1 minute';
  v_rate_limit_max     constant int      := 10;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Rate limit BEFORE the code lookup so the error-kind itself
  -- (not_found vs already_used) can't be used as a brute-force oracle.
  SELECT count(*) INTO v_recent_attempts
  FROM public.invite_redeem_attempts
  WHERE user_id = v_user
    AND attempted_at > now() - v_rate_limit_window;

  IF v_recent_attempts >= v_rate_limit_max THEN
    RETURN jsonb_build_object(
      'error', 'rate_limited',
      'retry_after_seconds', 60
    );
  END IF;

  v_normalized := upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
  IF length(v_normalized) = 0 THEN
    INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
    VALUES (v_user, NULL, false);
    RETURN jsonb_build_object('error', 'code_empty');
  END IF;

  SELECT * INTO v_code
  FROM public.organization_invite_codes
  WHERE code = v_normalized
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
    VALUES (v_user, v_normalized, false);
    RETURN jsonb_build_object('error', 'code_not_found');
  END IF;

  IF v_code.used_at IS NOT NULL THEN
    IF v_code.used_by_user_id = v_user THEN
      INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
      VALUES (v_user, v_normalized, true);
      RETURN jsonb_build_object(
        'ok', true,
        'org_id', v_code.org_id,
        'role', v_code.role,
        'label', v_code.label,
        'already_redeemed', true
      );
    END IF;
    INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
    VALUES (v_user, v_normalized, false);
    RETURN jsonb_build_object('error', 'code_already_used');
  END IF;

  IF v_code.expires_at IS NOT NULL AND v_code.expires_at < now() THEN
    INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
    VALUES (v_user, v_normalized, false);
    RETURN jsonb_build_object('error', 'code_expired');
  END IF;

  UPDATE public.organization_invite_codes
  SET used_by_user_id = v_user,
      used_at = now()
  WHERE id = v_code.id AND used_at IS NULL;

  IF NOT FOUND THEN
    INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
    VALUES (v_user, v_normalized, false);
    RETURN jsonb_build_object('error', 'code_already_used');
  END IF;

  SELECT * INTO v_existing
  FROM public.organization_members
  WHERE org_id = v_code.org_id AND user_id = v_user
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.organization_members
    SET status = 'active',
        role = COALESCE(role, v_code.role),
        joined_at = COALESCE(joined_at, now())
    WHERE id = v_existing.id;
  ELSE
    INSERT INTO public.organization_members (org_id, user_id, role, status, joined_at)
    VALUES (v_code.org_id, v_user, v_code.role, 'active', now());
  END IF;

  INSERT INTO public.invite_redeem_attempts (user_id, attempted_code, success)
  VALUES (v_user, v_normalized, true);

  RETURN jsonb_build_object(
    'ok', true,
    'org_id', v_code.org_id,
    'role', v_code.role,
    'label', v_code.label
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_invite_code(text) TO anon, authenticated;

-- 3) Regenerated code generator: 6-digit numeric, zero-padded.
CREATE OR REPLACE FUNCTION public.generate_invite_codes(
  p_slug text,
  p_count int,
  p_label_prefix text DEFAULT 'Student ',
  p_role text DEFAULT 'student',
  p_expires_at timestamptz DEFAULT NULL
) RETURNS TABLE (code text, label text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id uuid;
  v_user   uuid := auth.uid();
  v_code   text;
  v_label  text;
  v_i      int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT id INTO v_org_id FROM public.organizations WHERE slug = p_slug;
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'org slug % not found', p_slug;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE org_id = v_org_id
      AND user_id = v_user
      AND role IN ('owner', 'admin')
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'caller is not owner/admin of %', p_slug;
  END IF;

  FOR v_i IN 1..p_count LOOP
    -- 10^6 = 1M code space. Collision retry loop keeps us safe as the
    -- space fills up per-org (unique constraint is global on `code`).
    LOOP
      v_code := lpad(floor(random() * 1000000)::int::text, 6, '0');
      v_label := p_label_prefix || lpad(v_i::text, 2, '0');
      BEGIN
        INSERT INTO public.organization_invite_codes (org_id, code, role, label, expires_at, created_by)
        VALUES (v_org_id, v_code, p_role, v_label, p_expires_at, v_user);
        code := v_code;
        label := v_label;
        RETURN NEXT;
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        CONTINUE;
      END;
    END LOOP;
  END LOOP;
  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_invite_codes(text, int, text, text, timestamptz) TO authenticated;
