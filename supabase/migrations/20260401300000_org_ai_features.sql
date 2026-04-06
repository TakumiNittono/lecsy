-- B2B AI機能: 組織用語集 + AI使用ログ
-- Phase 1: 多言語クロス要約 + カスタム用語集生成

-- ============================================
-- 1. org_glossaries（組織専用用語集）
-- ============================================
CREATE TABLE org_glossaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    term TEXT NOT NULL,
    definition TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'en',
    category TEXT,  -- 任意のカテゴリタグ（例: 'grammar', 'business', 'medical'）
    source_transcript_id UUID REFERENCES transcripts(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(org_id, term, language)
);

CREATE INDEX idx_org_glossaries_org ON org_glossaries(org_id);
CREATE INDEX idx_org_glossaries_lang ON org_glossaries(org_id, language);
CREATE INDEX idx_org_glossaries_category ON org_glossaries(org_id, category);

CREATE TRIGGER update_org_glossaries_updated_at
    BEFORE UPDATE ON org_glossaries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. org_ai_usage_logs（B2B AI使用ログ）
-- ============================================
CREATE TABLE org_ai_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('cross_summary', 'glossary_generate')),
    transcript_id UUID REFERENCES transcripts(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_org_ai_logs_org ON org_ai_usage_logs(org_id);
CREATE INDEX idx_org_ai_logs_user ON org_ai_usage_logs(org_id, user_id);
CREATE INDEX idx_org_ai_logs_action ON org_ai_usage_logs(org_id, action, created_at);

-- ============================================
-- 3. RLS有効化
-- ============================================
ALTER TABLE org_glossaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_ai_usage_logs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. org_glossaries RLSポリシー
-- ============================================

-- 組織メンバーなら閲覧可
CREATE POLICY "glossary_select_member" ON org_glossaries FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = org_glossaries.org_id
        AND organization_members.user_id = (SELECT auth.uid())
    )
);

-- teacher以上なら追加可
CREATE POLICY "glossary_insert_teacher" ON org_glossaries FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = org_glossaries.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin', 'teacher')
    )
);

-- teacher以上なら更新可
CREATE POLICY "glossary_update_teacher" ON org_glossaries FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = org_glossaries.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin', 'teacher')
    )
);

-- admin以上なら削除可
CREATE POLICY "glossary_delete_admin" ON org_glossaries FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = org_glossaries.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin')
    )
);

-- ============================================
-- 5. org_ai_usage_logs RLSポリシー
-- ============================================

-- teacher以上なら組織のログ閲覧可
CREATE POLICY "ai_logs_select_teacher" ON org_ai_usage_logs FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = org_ai_usage_logs.org_id
        AND organization_members.user_id = (SELECT auth.uid())
        AND organization_members.role IN ('owner', 'admin', 'teacher')
    )
);

-- 組織メンバーなら自分のログをINSERT可
CREATE POLICY "ai_logs_insert_member" ON org_ai_usage_logs FOR INSERT WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_members.org_id = org_ai_usage_logs.org_id
        AND organization_members.user_id = (SELECT auth.uid())
    )
);
