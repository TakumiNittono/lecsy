-- v4 M1: transcripts に組織コンテキストを追加

ALTER TABLE transcripts
  ADD COLUMN IF NOT EXISTS organization_id UUID NULL REFERENCES organizations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('private', 'class', 'org_wide')),
  ADD COLUMN IF NOT EXISTS class_id UUID NULL;

CREATE INDEX IF NOT EXISTS idx_transcripts_org
  ON transcripts(organization_id)
  WHERE organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transcripts_class
  ON transcripts(class_id)
  WHERE class_id IS NOT NULL;

-- RLS: 組織のteacher以上は visibility >= 'class' を閲覧可
CREATE POLICY "transcripts_select_org_staff" ON transcripts FOR SELECT USING (
  organization_id IS NOT NULL
  AND visibility IN ('class', 'org_wide')
  AND is_org_role_at_least(organization_id, (SELECT auth.uid()), 'teacher')
);

-- 組織全体公開の場合、同組織の全アクティブメンバーが閲覧可
CREATE POLICY "transcripts_select_org_wide" ON transcripts FOR SELECT USING (
  organization_id IS NOT NULL
  AND visibility = 'org_wide'
  AND is_org_member(organization_id, (SELECT auth.uid()))
);
