-- 招待テーブル廃止 → メンバー直接追加方式に移行
-- organization_invites を DROP し、organization_members に email + status を追加

-- ============================================
-- 1. organization_invites のRLSポリシー削除 → テーブルDROP
-- ============================================
DROP POLICY IF EXISTS "invites_select_admin" ON organization_invites;
DROP POLICY IF EXISTS "invites_select_own" ON organization_invites;
DROP POLICY IF EXISTS "invites_insert_admin" ON organization_invites;
DROP POLICY IF EXISTS "invites_delete_admin" ON organization_invites;
DROP POLICY IF EXISTS "invites_update_admin" ON organization_invites;
DROP POLICY IF EXISTS "invites_update_own" ON organization_invites;
DROP POLICY IF EXISTS "invites_select_superadmin" ON organization_invites;
DROP POLICY IF EXISTS "invites_insert_superadmin" ON organization_invites;
DROP POLICY IF EXISTS "invites_delete_superadmin" ON organization_invites;
DROP POLICY IF EXISTS "invites_update_superadmin" ON organization_invites;

DROP TABLE IF EXISTS organization_invites;

-- ============================================
-- 2. organization_members に email + status 追加
-- ============================================

-- email: Admin がメールで追加 → ユーザーがログインしたら user_id 紐付け
-- pending 状態では user_id は NULL になる
ALTER TABLE organization_members
    ADD COLUMN email TEXT;

-- user_id を NULL 許容に変更（pending メンバーは user_id なし）
ALTER TABLE organization_members
    ALTER COLUMN user_id DROP NOT NULL;

-- UNIQUE制約: 同じ組織に同じメールは1つだけ
CREATE UNIQUE INDEX idx_org_members_email ON organization_members(org_id, email)
    WHERE email IS NOT NULL;

-- pending メンバーをメールで素早く検索
CREATE INDEX idx_org_members_status ON organization_members(status, email)
    WHERE status = 'pending';

-- ============================================
-- 3. 既存の members_insert_self ポリシーを更新
--    Admin/Owner がpendingメンバーを追加できるようにする
-- ============================================
DROP POLICY IF EXISTS "members_insert_self" ON organization_members;

-- admin/owner は自組織にメンバーを追加可
CREATE POLICY "members_insert_admin" ON organization_members FOR INSERT WITH CHECK (
    -- 自分自身を追加（組織作成時のowner登録）
    (user_id = (SELECT auth.uid()))
    OR
    -- admin/owner が他メンバーを追加（pending含む）
    EXISTS (
        SELECT 1 FROM organization_members AS om
        WHERE om.org_id = organization_members.org_id
        AND om.user_id = (SELECT auth.uid())
        AND om.role IN ('owner', 'admin')
    )
);

-- ============================================
-- 4. ログイン時の自動アクティベーション関数
--    メールが一致する pending メンバーに user_id を紐付けて active にする
-- ============================================
CREATE OR REPLACE FUNCTION activate_pending_memberships(p_user_id UUID, p_email TEXT)
RETURNS SETOF organization_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    UPDATE organization_members
    SET user_id = p_user_id,
        status = 'active'
    WHERE email = lower(p_email)
    AND status = 'pending'
    AND user_id IS NULL
    RETURNING *;
END;
$$;
