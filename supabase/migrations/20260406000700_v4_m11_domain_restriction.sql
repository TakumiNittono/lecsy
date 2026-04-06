-- v4 M11: ドメイン制限を members_insert ポリシーに統合

DROP POLICY IF EXISTS "members_insert_admin" ON organization_members;

CREATE POLICY "members_insert_admin" ON organization_members FOR INSERT WITH CHECK (
  -- 自分自身を追加（組織作成時のowner登録 or 自己参加）
  (user_id = (SELECT auth.uid()))
  OR
  -- admin/owner が他メンバーを追加
  EXISTS (
    SELECT 1
    FROM organization_members AS om
    JOIN organizations o ON o.id = om.org_id
    WHERE om.org_id = organization_members.org_id
      AND om.user_id = (SELECT auth.uid())
      AND om.role IN ('owner', 'admin')
      AND om.status = 'active'
      AND (
        coalesce(array_length(o.allowed_email_domains, 1), 0) = 0
        OR organization_members.email IS NULL
        OR email_domain(organization_members.email) = ANY(o.allowed_email_domains)
      )
  )
);
