-- lecsy Supabase 初期スキーマ
-- Phase 0: データベース設定

-- ============================================
-- 1. updated_at 自動更新関数
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================
-- 2. transcripts（文字起こしテキスト）
-- ============================================
CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    source TEXT DEFAULT 'ios',
    word_count INTEGER,
    language TEXT,
    duration INTEGER,  -- 秒単位
    
    CONSTRAINT content_not_empty CHECK (content <> '')
);

-- インデックス
CREATE INDEX idx_transcripts_user_id ON transcripts(user_id);
CREATE INDEX idx_transcripts_created_at ON transcripts(created_at DESC);
CREATE INDEX idx_transcripts_user_created ON transcripts(user_id, created_at DESC);

-- updated_at 自動更新トリガー
CREATE TRIGGER update_transcripts_updated_at
    BEFORE UPDATE ON transcripts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 3. summaries（AI要約結果）
-- ============================================
CREATE TABLE summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_id UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    summary TEXT,
    key_points JSONB,        -- ["ポイント1", "ポイント2", ...]
    sections JSONB,          -- [{"heading": "...", "content": "..."}, ...]
    exam_mode JSONB,         -- {"key_terms": [...], "questions": [...], "predictions": [...]}
    model TEXT DEFAULT 'gpt-4-turbo',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT one_summary_per_transcript UNIQUE (transcript_id)
);

-- インデックス
CREATE INDEX idx_summaries_transcript_id ON summaries(transcript_id);
CREATE INDEX idx_summaries_user_id ON summaries(user_id);

-- updated_at 自動更新
CREATE TRIGGER update_summaries_updated_at
    BEFORE UPDATE ON summaries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 4. subscriptions（サブスクリプション状態）
-- ============================================
CREATE TABLE subscriptions (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'free',  -- 'free', 'active', 'canceled', 'past_due'
    provider TEXT,                        -- 'stripe', 'appstore'
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_status CHECK (status IN ('free', 'active', 'canceled', 'past_due'))
);

-- インデックス
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_stripe_customer ON subscriptions(stripe_customer_id);

-- updated_at 自動更新
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. usage_logs（AI使用量ログ）
-- ============================================
CREATE TABLE usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,        -- 'summarize', 'exam_mode'
    transcript_id UUID REFERENCES transcripts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_action CHECK (action IN ('summarize', 'exam_mode'))
);

-- インデックス
CREATE INDEX idx_usage_logs_user_created ON usage_logs(user_id, created_at DESC);
CREATE INDEX idx_usage_logs_user_action_created ON usage_logs(user_id, action, created_at DESC);

-- ============================================
-- 6. Row Level Security (RLS) 有効化
-- ============================================
ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_logs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 7. transcripts RLS ポリシー
-- ============================================
-- 自分の文字起こしのみ閲覧可能
CREATE POLICY "Users can view own transcripts"
    ON transcripts FOR SELECT
    USING (auth.uid() = user_id);

-- 自分の文字起こしのみ作成可能
CREATE POLICY "Users can insert own transcripts"
    ON transcripts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 自分の文字起こしのみ更新可能
CREATE POLICY "Users can update own transcripts"
    ON transcripts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 自分の文字起こしのみ削除可能
CREATE POLICY "Users can delete own transcripts"
    ON transcripts FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- 8. summaries RLS ポリシー
-- ============================================
-- 自分の要約のみ閲覧可能
CREATE POLICY "Users can view own summaries"
    ON summaries FOR SELECT
    USING (auth.uid() = user_id);

-- 自分の要約のみ作成可能（Edge Function経由）
CREATE POLICY "Users can insert own summaries"
    ON summaries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 自分の要約のみ更新可能
CREATE POLICY "Users can update own summaries"
    ON summaries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 9. subscriptions RLS ポリシー
-- ============================================
-- 自分のサブスクリプションのみ閲覧可能
CREATE POLICY "Users can view own subscription"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- サブスクリプションの作成・更新・削除はサービスロールのみ（Edge Functionから）
-- INSERT/UPDATE/DELETE ポリシーは作成しない（サービスロール専用）

-- ============================================
-- 10. usage_logs RLS ポリシー
-- ============================================
-- 自分の使用ログのみ閲覧可能
CREATE POLICY "Users can view own usage logs"
    ON usage_logs FOR SELECT
    USING (auth.uid() = user_id);

-- 使用ログの作成はサービスロールのみ（Edge Functionから）
-- INSERT ポリシーは作成しない（サービスロール専用）
