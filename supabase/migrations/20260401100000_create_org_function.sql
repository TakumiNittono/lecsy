-- 組織作成 + owner登録をアトミックに行うDB関数
-- RLSのSELECTポリシー（メンバーのみ）とINSERT後のID取得の鶏卵問題を回避

-- status カラムを先に追加（この後の関数で参照するため）
ALTER TABLE organization_members
    ADD COLUMN status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('pending', 'active'));

CREATE OR REPLACE FUNCTION create_organization(
  p_name TEXT,
  p_slug TEXT,
  p_type TEXT DEFAULT 'language_school'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_user_id UUID;
BEGIN
  -- 呼び出し元のユーザーIDを取得
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 組織を作成
  INSERT INTO organizations (name, slug, type)
  VALUES (p_name, p_slug, p_type)
  RETURNING id INTO v_org_id;

  -- 作成者をownerとして登録（active状態）
  INSERT INTO organization_members (org_id, user_id, role, status)
  VALUES (v_org_id, v_user_id, 'owner', 'active');
END;
$$;
