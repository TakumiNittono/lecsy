-- スーパー管理者（nittonotakumi@gmail.com）が全組織・メンバーを閲覧可能にする

-- organizations: スーパー管理者は全組織を閲覧可
CREATE POLICY "org_select_superadmin" ON organizations FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

-- organizations: スーパー管理者は全組織を更新可
CREATE POLICY "org_update_superadmin" ON organizations FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

-- organizations: スーパー管理者は全組織を削除可
CREATE POLICY "org_delete_superadmin" ON organizations FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

-- organization_members: スーパー管理者は全メンバーを閲覧可
CREATE POLICY "members_select_superadmin" ON organization_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

-- organization_members: スーパー管理者は全メンバーを管理可
CREATE POLICY "members_insert_superadmin" ON organization_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

CREATE POLICY "members_delete_superadmin" ON organization_members FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

CREATE POLICY "members_update_superadmin" ON organization_members FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

-- organization_invites: スーパー管理者は全招待を閲覧可
CREATE POLICY "invites_select_superadmin" ON organization_invites FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

CREATE POLICY "invites_insert_superadmin" ON organization_invites FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

CREATE POLICY "invites_delete_superadmin" ON organization_invites FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);

CREATE POLICY "invites_update_superadmin" ON organization_invites FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = (SELECT auth.uid())
    AND auth.users.email = 'nittonotakumi@gmail.com'
  )
);
