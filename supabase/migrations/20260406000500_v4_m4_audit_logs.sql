-- v4 M4 + M10: audit_logs

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  actor_user_id UUID REFERENCES auth.users(id),
  actor_email TEXT,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_org_time ON audit_logs(org_id, created_at DESC);
CREATE INDEX idx_audit_actor_time ON audit_logs(actor_user_id, created_at DESC);
CREATE INDEX idx_audit_action_time ON audit_logs(action, created_at DESC);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- admin以上のみ閲覧可
CREATE POLICY "audit_select_admin" ON audit_logs FOR SELECT USING (
  org_id IS NOT NULL
  AND is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

-- 直接INSERT禁止（SECURITY DEFINER関数経由のみ）
-- ポリシーを作らないことで全userからのINSERTを拒否

-- ログ書き込み用のSECURITY DEFINER関数
CREATE OR REPLACE FUNCTION write_audit_log(
  p_org_id UUID,
  p_action TEXT,
  p_target_type TEXT DEFAULT NULL,
  p_target_id TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_email TEXT;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = (SELECT auth.uid());

  INSERT INTO audit_logs (org_id, actor_user_id, actor_email, action, target_type, target_id, metadata)
  VALUES (p_org_id, (SELECT auth.uid()), v_email, p_action, p_target_type, p_target_id, p_metadata)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
