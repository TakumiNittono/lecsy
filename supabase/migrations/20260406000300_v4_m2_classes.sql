-- v4 M2 + M8: org_classes / org_class_members

CREATE TABLE org_classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  semester TEXT,
  start_date DATE,
  end_date DATE,
  archived BOOLEAN NOT NULL DEFAULT false,
  teacher_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_org_classes_org ON org_classes(org_id);
CREATE INDEX idx_org_classes_active ON org_classes(org_id) WHERE NOT archived;
CREATE INDEX idx_org_classes_teacher ON org_classes(teacher_id) WHERE teacher_id IS NOT NULL;

CREATE TRIGGER update_org_classes_updated_at
  BEFORE UPDATE ON org_classes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE org_class_members (
  class_id UUID NOT NULL REFERENCES org_classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (class_id, user_id)
);

CREATE INDEX idx_class_members_user ON org_class_members(user_id);

ALTER TABLE org_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_class_members ENABLE ROW LEVEL SECURITY;

-- 同組織のactiveメンバーは閲覧可
CREATE POLICY "classes_select_member" ON org_classes FOR SELECT USING (
  is_org_member(org_id, (SELECT auth.uid()))
);

-- teacher以上が作成可
CREATE POLICY "classes_insert_teacher" ON org_classes FOR INSERT WITH CHECK (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'teacher')
);

CREATE POLICY "classes_update_teacher" ON org_classes FOR UPDATE USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'teacher')
);

CREATE POLICY "classes_delete_admin" ON org_classes FOR DELETE USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);

-- class_members: 同組織メンバーが閲覧可
CREATE POLICY "class_members_select" ON org_class_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM org_classes c
    WHERE c.id = org_class_members.class_id
      AND is_org_member(c.org_id, (SELECT auth.uid()))
  )
);

CREATE POLICY "class_members_insert_teacher" ON org_class_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM org_classes c
    WHERE c.id = org_class_members.class_id
      AND is_org_role_at_least(c.org_id, (SELECT auth.uid()), 'teacher')
  )
);

CREATE POLICY "class_members_delete_teacher" ON org_class_members FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM org_classes c
    WHERE c.id = org_class_members.class_id
      AND is_org_role_at_least(c.org_id, (SELECT auth.uid()), 'teacher')
  )
);

-- transcripts.class_id の FK を遅延設定（M1 の後に）
ALTER TABLE transcripts
  ADD CONSTRAINT fk_transcripts_class
  FOREIGN KEY (class_id) REFERENCES org_classes(id) ON DELETE SET NULL;

-- 同クラスメンバーは visibility='class' の transcript を閲覧可
CREATE POLICY "transcripts_select_class_member" ON transcripts FOR SELECT USING (
  class_id IS NOT NULL
  AND visibility = 'class'
  AND EXISTS (
    SELECT 1 FROM org_class_members cm
    WHERE cm.class_id = transcripts.class_id
      AND cm.user_id = (SELECT auth.uid())
  )
);
