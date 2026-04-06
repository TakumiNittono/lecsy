-- v4 M3: org_glossary

CREATE TABLE org_glossary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  term TEXT NOT NULL,
  definition TEXT NOT NULL,
  example TEXT,
  source_language TEXT NOT NULL DEFAULT 'en',
  target_language TEXT NOT NULL,
  translation TEXT,
  difficulty TEXT CHECK (difficulty IN ('beginner','intermediate','advanced')) DEFAULT 'intermediate',
  source_transcript_id UUID REFERENCES transcripts(id) ON DELETE SET NULL,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(org_id, term, target_language)
);

CREATE INDEX idx_glossary_org ON org_glossary(org_id);
CREATE INDEX idx_glossary_term ON org_glossary(org_id, term);

CREATE TRIGGER update_glossary_updated_at
  BEFORE UPDATE ON org_glossary
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE org_glossary ENABLE ROW LEVEL SECURITY;

CREATE POLICY "glossary_select_member" ON org_glossary FOR SELECT USING (
  is_org_member(org_id, (SELECT auth.uid()))
);

CREATE POLICY "glossary_insert_teacher" ON org_glossary FOR INSERT WITH CHECK (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'teacher')
);

CREATE POLICY "glossary_update_teacher" ON org_glossary FOR UPDATE USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'teacher')
);

CREATE POLICY "glossary_delete_admin" ON org_glossary FOR DELETE USING (
  is_org_role_at_least(org_id, (SELECT auth.uid()), 'admin')
);
