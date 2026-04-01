-- B2B組織管理テーブル
-- organizations, organization_members, organization_invites

-- ============================================
-- 1. organizations（組織）
-- ============================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL DEFAULT 'language_school'
        CHECK (type IN ('language_school', 'university_iep', 'college', 'corporate')),
    plan TEXT NOT NULL DEFAULT 'starter'
        CHECK (plan IN ('starter', 'growth', 'enterprise')),
    max_seats INTEGER NOT NULL DEFAULT 50,
    logo_url TEXT,
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_stripe ON organizations(stripe_customer_id);

CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. organization_members（メンバー）
-- ============================================
CREATE TABLE organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'student'
        CHECK (role IN ('owner', 'admin', 'teacher', 'student')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(org_id, user_id)
);

CREATE INDEX idx_org_members_org ON organization_members(org_id);
CREATE INDEX idx_org_members_user ON organization_members(user_id);
CREATE INDEX idx_org_members_role ON organization_members(org_id, role);

-- ============================================
-- 3. organization_invites（招待）
-- ============================================
CREATE TABLE organization_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'student'
        CHECK (role IN ('admin', 'teacher', 'student')),
    token TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
    invited_by UUID NOT NULL REFERENCES auth.users(id),
    accepted BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_org_invites_token ON organization_invites(token);
CREATE INDEX idx_org_invites_email ON organization_invites(email);
CREATE INDEX idx_org_invites_org ON organization_invites(org_id);

-- ============================================
-- 4. RLS有効化
-- ============================================
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_invites ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 5. organizations RLSポリシー
-- ============================================

-- メンバーなら閲覧可
CREATE POLICY "org_select_member" ON organizations FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organizations.id
        AND organization_members.user_id = (SELECT auth.uid())
    )
);

-- owner/adminのみ更新可
CREATE POLICY "org_update_admin" ON organizations FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organizations.id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin')
    )
);

-- 認証済みユーザーなら作成可（組織作成時）
CREATE POLICY "org_insert_authenticated" ON organizations FOR INSERT
    WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- ownerのみ削除可
CREATE POLICY "org_delete_owner" ON organizations FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organizations.id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role = 'owner'
    )
);

-- ============================================
-- 6. organization_members RLSポリシー
-- ============================================

-- 同組織のメンバーなら閲覧可
CREATE POLICY "members_select" ON organization_members FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM organization_members AS om
        WHERE om.org_id = organization_members.org_id
        AND om.user_id = (SELECT auth.uid())
    )
);

-- 認証済みユーザーなら自分自身をINSERT可（組織作成時のowner登録 + 招待受諾時）
CREATE POLICY "members_insert_self" ON organization_members FOR INSERT
    WITH CHECK (user_id = (SELECT auth.uid()));

-- owner/adminのみ他メンバーを削除可
CREATE POLICY "members_delete_admin" ON organization_members FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM organization_members AS om
        WHERE om.org_id = organization_members.org_id
        AND om.user_id = (SELECT auth.uid())
        AND om.role IN ('owner', 'admin')
    )
);

-- owner/adminのみロール更新可
CREATE POLICY "members_update_admin" ON organization_members FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM organization_members AS om
        WHERE om.org_id = organization_members.org_id
        AND om.user_id = (SELECT auth.uid())
        AND om.role IN ('owner', 'admin')
    )
);

-- ============================================
-- 7. organization_invites RLSポリシー
-- ============================================

-- owner/adminが招待閲覧可
CREATE POLICY "invites_select_admin" ON organization_invites FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organization_invites.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin')
    )
);

-- 招待されたユーザー自身も自分の招待を閲覧可（トークンで受諾するため）
CREATE POLICY "invites_select_own" ON organization_invites FOR SELECT USING (
    email = (SELECT auth.users.email FROM auth.users WHERE auth.users.id = (SELECT auth.uid()))
);

-- owner/adminが招待作成可
CREATE POLICY "invites_insert_admin" ON organization_invites FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organization_invites.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin')
    )
);

-- owner/adminが招待削除可（キャンセル）
CREATE POLICY "invites_delete_admin" ON organization_invites FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organization_invites.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin')
    )
);

-- owner/adminが招待更新可（accepted = trueに変更）
CREATE POLICY "invites_update_admin" ON organization_invites FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = organization_invites.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin')
    )
);

-- 招待されたユーザー自身も更新可（受諾時）
CREATE POLICY "invites_update_own" ON organization_invites FOR UPDATE USING (
    email = (SELECT auth.users.email FROM auth.users WHERE auth.users.id = (SELECT auth.uid()))
);
