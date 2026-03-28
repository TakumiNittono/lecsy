-- ============================================
-- reports（問題報告・フィードバック）
-- ============================================
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    email TEXT,
    category TEXT NOT NULL DEFAULT 'bug',
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    device_info TEXT,
    app_version TEXT,
    platform TEXT DEFAULT 'ios',
    status TEXT NOT NULL DEFAULT 'open',
    admin_note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_category CHECK (category IN ('bug', 'crash', 'feature', 'transcription', 'sync', 'account', 'other')),
    CONSTRAINT valid_status CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    CONSTRAINT description_not_empty CHECK (description <> '')
);

-- インデックス
CREATE INDEX idx_reports_user_id ON reports(user_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_category ON reports(category);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);

-- updated_at 自動更新トリガー
CREATE TRIGGER update_reports_updated_at
    BEFORE UPDATE ON reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- RLS
-- ============================================
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の報告のみ閲覧可能
CREATE POLICY "Users can view own reports"
    ON reports FOR SELECT
    USING (auth.uid() = user_id);

-- 認証済みユーザーは自分の報告を作成可能
CREATE POLICY "Users can insert own reports"
    ON reports FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 未認証ユーザーからの報告はEdge Function（service_role）経由で挿入
-- INSERT without user_id は service_role のみ
