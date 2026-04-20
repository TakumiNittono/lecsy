-- Classroom-pilot invite codes
--
-- Why: US 大学 / コミカレ (FMCC, Santa Fe 等) の Microsoft 365 テナントは、
-- 新規ドメインからの OTP メールをデフォルトで Junk / 3 分遅延に落とす。
-- メール認証は教室パイロットでは実用に耐えない (Kim のクラスで検証済)。
-- そこで教員が紙 / QR で配布できる 6 桁使い捨てコードを導入する:
--   1. 事前に admin が org_id 毎に N 個のコードを発行
--   2. 教員がコードを印刷 (or QR 化) して教室で配布
--   3. 学生は iOS / Web の "Have an invite code?" 欄にタイプ
--   4. アプリが supabase.auth.signInAnonymously() → redeem_invite_code RPC
--   5. anon ユーザが organization_members に active として即紐づく
--
-- メール / OAuth / Microsoft consent をすべて回避する。コードは 1 回使い切り。

CREATE TABLE IF NOT EXISTS public.organization_invite_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  code text NOT NULL,
  role text NOT NULL DEFAULT 'student',
  label text, -- e.g. "Student 01" or "Jennifer" for roster display
  used_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  used_at timestamptz,
  expires_at timestamptz,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT organization_invite_codes_code_unique UNIQUE (code),
  CONSTRAINT organization_invite_codes_role_check
    CHECK (role IN ('owner', 'admin', 'teacher', 'student'))
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_org
  ON public.organization_invite_codes (org_id);

-- Partial index for the common "find unused code" lookup during redeem.
CREATE INDEX IF NOT EXISTS idx_invite_codes_unused
  ON public.organization_invite_codes (code)
  WHERE used_at IS NULL;

ALTER TABLE public.organization_invite_codes ENABLE ROW LEVEL SECURITY;

-- Org staff (owner/admin/teacher) can see their org's codes (for the
-- dashboard listing / re-print workflow). Students never query this table
-- directly — they hit the redeem RPC below.
CREATE POLICY "invite_codes_read_by_staff"
  ON public.organization_invite_codes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organization_invite_codes.org_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role IN ('owner', 'admin', 'teacher')
        AND m.status = 'active'
    )
  );

-- Only owner/admin can mint / delete codes.
CREATE POLICY "invite_codes_insert_by_admin"
  ON public.organization_invite_codes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organization_invite_codes.org_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role IN ('owner', 'admin')
        AND m.status = 'active'
    )
  );

CREATE POLICY "invite_codes_delete_by_admin"
  ON public.organization_invite_codes FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organization_invite_codes.org_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role IN ('owner', 'admin')
        AND m.status = 'active'
    )
  );

-- Redeem function.
-- SECURITY DEFINER so we can read / update the invite row even though the
-- caller (anonymous user) has no RLS permission on organization_invite_codes.
-- Also lets us INSERT into organization_members on the caller's behalf.
-- We intentionally do NOT expose the invite row itself — only the minimal
-- fields the client needs (org_id, role, label).
CREATE OR REPLACE FUNCTION public.redeem_invite_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_code   public.organization_invite_codes;
  v_user   uuid := auth.uid();
  v_existing public.organization_members;
  v_normalized text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Normalize: strip whitespace, uppercase, strip dashes so e.g. "k4-m2-p9"
  -- and "K4M2P9" both match.
  v_normalized := upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
  IF length(v_normalized) = 0 THEN
    RETURN jsonb_build_object('error', 'code_empty');
  END IF;

  SELECT * INTO v_code
  FROM public.organization_invite_codes
  WHERE code = v_normalized
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'code_not_found');
  END IF;

  IF v_code.used_at IS NOT NULL THEN
    -- Idempotent: if THIS user already redeemed this code, return success so
    -- the app doesn't ping-pong on retries. Otherwise it's taken.
    IF v_code.used_by_user_id = v_user THEN
      RETURN jsonb_build_object(
        'ok', true,
        'org_id', v_code.org_id,
        'role', v_code.role,
        'label', v_code.label,
        'already_redeemed', true
      );
    END IF;
    RETURN jsonb_build_object('error', 'code_already_used');
  END IF;

  IF v_code.expires_at IS NOT NULL AND v_code.expires_at < now() THEN
    RETURN jsonb_build_object('error', 'code_expired');
  END IF;

  -- Mark code used atomically (guard against a race between two users
  -- typing the same code). The WHERE used_at IS NULL clause means only
  -- the first caller wins.
  UPDATE public.organization_invite_codes
  SET used_by_user_id = v_user,
      used_at = now()
  WHERE id = v_code.id AND used_at IS NULL;

  IF NOT FOUND THEN
    -- Lost the race; someone else redeemed it between SELECT and UPDATE.
    RETURN jsonb_build_object('error', 'code_already_used');
  END IF;

  -- Ensure org_member row exists and is active for this user.
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

  RETURN jsonb_build_object(
    'ok', true,
    'org_id', v_code.org_id,
    'role', v_code.role,
    'label', v_code.label
  );
END;
$$;

-- Anonymous callers need EXECUTE (that's the whole point).
GRANT EXECUTE ON FUNCTION public.redeem_invite_code(text) TO anon, authenticated;

-- Helper to bulk-generate codes from SQL editor.
-- Usage:
--   select * from generate_invite_codes(
--     p_slug := 'fmcc-pilot',
--     p_count := 10,
--     p_label_prefix := 'Student '
--   );
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
  v_user uuid := auth.uid();
  -- Unambiguous charset: no O/0, I/1, confusing lowercase. 32 chars.
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_label text;
  v_i int;
  v_j int;
  v_len int := 6;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT id INTO v_org_id FROM public.organizations WHERE slug = p_slug;
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'org slug % not found', p_slug;
  END IF;

  -- Caller must be owner/admin of the target org.
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
    -- Retry loop in case of code collision (extremely rare for 32^6).
    LOOP
      v_code := '';
      FOR v_j IN 1..v_len LOOP
        v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
      END LOOP;

      v_label := p_label_prefix || lpad(v_i::text, 2, '0');
      BEGIN
        INSERT INTO public.organization_invite_codes (org_id, code, role, label, expires_at, created_by)
        VALUES (v_org_id, v_code, p_role, v_label, p_expires_at, v_user);
        -- Success: return it
        code := v_code;
        label := v_label;
        RETURN NEXT;
        EXIT; -- exit retry loop
      EXCEPTION WHEN unique_violation THEN
        -- Collision; try another random code.
        CONTINUE;
      END;
    END LOOP;
  END LOOP;
  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_invite_codes(text, int, text, text, timestamptz) TO authenticated;
