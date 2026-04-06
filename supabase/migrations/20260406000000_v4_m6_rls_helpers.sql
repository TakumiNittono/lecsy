-- v4 M6: RLS再帰解消ヘルパ関数
-- organization_members の自己参照ポリシーをSECURITY DEFINER関数に切り出す

CREATE OR REPLACE FUNCTION is_org_member(p_org UUID, p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM organization_members
    WHERE org_id = p_org
      AND user_id = p_user
      AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION is_org_role_at_least(p_org UUID, p_user UUID, p_min TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1
    FROM organization_members om
    WHERE om.org_id = p_org
      AND om.user_id = p_user
      AND om.status = 'active'
      AND CASE om.role
            WHEN 'owner'   THEN 3
            WHEN 'admin'   THEN 2
            WHEN 'teacher' THEN 1
            WHEN 'student' THEN 0
          END
          >=
          CASE p_min
            WHEN 'owner'   THEN 3
            WHEN 'admin'   THEN 2
            WHEN 'teacher' THEN 1
            WHEN 'student' THEN 0
          END
  );
$$;

CREATE OR REPLACE FUNCTION is_org_role_at_least_by_slug(p_slug TEXT, p_user UUID, p_min TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT is_org_role_at_least(o.id, p_user, p_min)
  FROM organizations o
  WHERE o.slug = p_slug;
$$;

-- 既存の自己参照ポリシーをヘルパに置き換え
DROP POLICY IF EXISTS "members_select" ON organization_members;
CREATE POLICY "members_select" ON organization_members FOR SELECT USING (
  is_org_member(org_id, (SELECT auth.uid()))
);

DROP POLICY IF EXISTS "members_delete_admin" ON organization_members;
CREATE POLICY "members_delete_admin" ON organization_members FOR DELETE USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

DROP POLICY IF EXISTS "members_update_admin" ON organization_members;
CREATE POLICY "members_update_admin" ON organization_members FOR UPDATE USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

DROP POLICY IF EXISTS "org_select_member" ON organizations;
CREATE POLICY "org_select_member" ON organizations FOR SELECT USING (
  is_org_member(id, (SELECT auth.uid()))
);

DROP POLICY IF EXISTS "org_update_admin" ON organizations;
CREATE POLICY "org_update_admin" ON organizations FOR UPDATE USING (
  is_org_role_at_least(id, (SELECT auth.uid()), 'admin')
);

DROP POLICY IF EXISTS "org_delete_owner" ON organizations;
CREATE POLICY "org_delete_owner" ON organizations FOR DELETE USING (
  is_org_role_at_least(id, (SELECT auth.uid()), 'owner')
);
