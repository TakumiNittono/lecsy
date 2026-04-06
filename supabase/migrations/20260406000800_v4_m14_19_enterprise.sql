-- v4 M14-M19: エンタープライズ機能（SSO/SCIM/Security/Billing/Deletion/Seats）

-- ============================================
-- M14. SSO 設定
-- ============================================
CREATE TABLE org_sso_configs (
  org_id UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  enforce_sso BOOLEAN NOT NULL DEFAULT false,
  protocol TEXT NOT NULL DEFAULT 'saml' CHECK (protocol IN ('saml','oidc')),
  idp_metadata_xml TEXT,
  idp_entity_id TEXT,
  idp_sso_url TEXT,
  idp_x509_cert TEXT,
  sp_entity_id TEXT,
  attr_email TEXT NOT NULL DEFAULT 'email',
  attr_first_name TEXT,
  attr_last_name TEXT,
  attr_groups TEXT,
  group_role_map JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE org_sso_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sso_select_admin" ON org_sso_configs FOR SELECT USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);
CREATE POLICY "sso_modify_owner" ON org_sso_configs FOR ALL USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'owner')
) WITH CHECK (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'owner')
);

CREATE TRIGGER update_sso_updated_at
  BEFORE UPDATE ON org_sso_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- M15. SCIM トークン
-- ============================================
CREATE TABLE org_scim_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  label TEXT,
  last_used_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_scim_org ON org_scim_tokens(org_id) WHERE revoked_at IS NULL;
CREATE UNIQUE INDEX idx_scim_token_hash ON org_scim_tokens(token_hash);

ALTER TABLE org_scim_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "scim_admin_only" ON org_scim_tokens FOR ALL USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

-- ============================================
-- M16. セキュリティポリシー
-- ============================================
CREATE TABLE org_security_policies (
  org_id UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  require_mfa_for_admins BOOLEAN NOT NULL DEFAULT false,
  ip_allowlist CIDR[] DEFAULT '{}',
  session_max_hours INT NOT NULL DEFAULT 24 CHECK (session_max_hours BETWEEN 1 AND 720),
  password_min_length INT NOT NULL DEFAULT 12 CHECK (password_min_length BETWEEN 8 AND 64),
  data_retention_days INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE org_security_policies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "security_select_member" ON org_security_policies FOR SELECT USING (
  is_org_member(org_id, (SELECT auth.uid()))
);
CREATE POLICY "security_modify_admin" ON org_security_policies FOR ALL USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
) WITH CHECK (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

-- ============================================
-- M17. 請求プロファイル + 請求書
-- ============================================
CREATE TABLE org_billing_profiles (
  org_id UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  legal_name TEXT NOT NULL,
  tax_id TEXT,
  billing_email TEXT NOT NULL,
  billing_address JSONB,
  payment_terms TEXT NOT NULL DEFAULT 'on_receipt'
    CHECK (payment_terms IN ('on_receipt','net15','net30','net60')),
  po_required BOOLEAN NOT NULL DEFAULT false,
  current_po_number TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE org_billing_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "billing_owner_only" ON org_billing_profiles FOR ALL USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'owner')
) WITH CHECK (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'owner')
);

CREATE TABLE org_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL UNIQUE,
  amount_cents INT NOT NULL CHECK (amount_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'usd',
  status TEXT NOT NULL CHECK (status IN ('draft','open','paid','void','uncollectible')),
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  due_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  pdf_url TEXT,
  stripe_invoice_id TEXT,
  line_items JSONB DEFAULT '[]'::jsonb
);

CREATE INDEX idx_invoices_org_status ON org_invoices(org_id, status);

ALTER TABLE org_invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "invoices_owner_select" ON org_invoices FOR SELECT USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

-- ============================================
-- M18. データ削除リクエスト
-- ============================================
CREATE TABLE data_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  requested_by UUID REFERENCES auth.users(id),
  subject_user_id UUID REFERENCES auth.users(id),
  scope TEXT NOT NULL CHECK (scope IN ('user','organization')),
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','completed','rejected')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_deletion_status ON data_deletion_requests(status);

ALTER TABLE data_deletion_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "deletion_select_self_or_admin" ON data_deletion_requests FOR SELECT USING (
  requested_by = (SELECT auth.uid())
  OR (org_id IS NOT NULL AND is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin'))
);
CREATE POLICY "deletion_insert_self" ON data_deletion_requests FOR INSERT WITH CHECK (
  requested_by = (SELECT auth.uid())
);

-- ============================================
-- M19. 席数スナップショット（True-up 課金用）
-- ============================================
CREATE TABLE org_seat_snapshots (
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  snapshot_date DATE NOT NULL,
  active_seats INT NOT NULL,
  pending_seats INT NOT NULL,
  PRIMARY KEY (org_id, snapshot_date)
);

CREATE INDEX idx_snapshots_date ON org_seat_snapshots(snapshot_date);

ALTER TABLE org_seat_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "snapshots_admin_select" ON org_seat_snapshots FOR SELECT USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

-- 日次スナップショットを記録する関数（cronから呼ぶ）
CREATE OR REPLACE FUNCTION snapshot_all_org_seats()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  INSERT INTO org_seat_snapshots (org_id, snapshot_date, active_seats, pending_seats)
  SELECT
    o.id,
    CURRENT_DATE,
    count(*) FILTER (WHERE m.status = 'active'),
    count(*) FILTER (WHERE m.status = 'pending')
  FROM organizations o
  LEFT JOIN organization_members m ON m.org_id = o.id
  GROUP BY o.id
  ON CONFLICT (org_id, snapshot_date) DO UPDATE
    SET active_seats = EXCLUDED.active_seats,
        pending_seats = EXCLUDED.pending_seats;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
