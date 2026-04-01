-- セキュリティ修正: Function Search Path & RLS Initplan
-- Ref: https://supabase.com/docs/guides/database/database-advisors

-- ============================================
-- 1. Function Search Path Mutable の修正
-- ============================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================
-- 2. Auth RLS Initplan の最適化
-- auth.uid() を (select auth.uid()) でラップし、
-- 行ごとではなくクエリごとに1回だけ評価されるようにする
-- ============================================

-- transcripts
DROP POLICY IF EXISTS "Users can view own transcripts" ON transcripts;
DROP POLICY IF EXISTS "Users can insert own transcripts" ON transcripts;
DROP POLICY IF EXISTS "Users can update own transcripts" ON transcripts;
DROP POLICY IF EXISTS "Users can delete own transcripts" ON transcripts;

CREATE POLICY "Users can view own transcripts"
    ON transcripts FOR SELECT
    USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own transcripts"
    ON transcripts FOR INSERT
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own transcripts"
    ON transcripts FOR UPDATE
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own transcripts"
    ON transcripts FOR DELETE
    USING ((SELECT auth.uid()) = user_id);

-- summaries
DROP POLICY IF EXISTS "Users can view own summaries" ON summaries;
DROP POLICY IF EXISTS "Users can insert own summaries" ON summaries;
DROP POLICY IF EXISTS "Users can update own summaries" ON summaries;

CREATE POLICY "Users can view own summaries"
    ON summaries FOR SELECT
    USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own summaries"
    ON summaries FOR INSERT
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own summaries"
    ON summaries FOR UPDATE
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- subscriptions
DROP POLICY IF EXISTS "Users can view own subscription" ON subscriptions;

CREATE POLICY "Users can view own subscription"
    ON subscriptions FOR SELECT
    USING ((SELECT auth.uid()) = user_id);

-- usage_logs
DROP POLICY IF EXISTS "Users can view own usage logs" ON usage_logs;

CREATE POLICY "Users can view own usage logs"
    ON usage_logs FOR SELECT
    USING ((SELECT auth.uid()) = user_id);
