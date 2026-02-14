-- Rate limit tracking table for Vercel serverless
-- In-memory rate limiting doesn't persist across serverless invocations,
-- so we use the database to track API usage.

CREATE TABLE IF NOT EXISTS public.rate_limit_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Index for fast rate limit lookups
CREATE INDEX idx_rate_limit_logs_lookup
  ON public.rate_limit_logs(user_id, action, created_at);

-- Enable RLS
ALTER TABLE public.rate_limit_logs ENABLE ROW LEVEL SECURITY;

-- Users can only insert their own entries
CREATE POLICY "rate_limit_logs_insert" ON public.rate_limit_logs
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

-- Users can only read their own entries
CREATE POLICY "rate_limit_logs_select" ON public.rate_limit_logs
  FOR SELECT USING ((SELECT auth.uid()) = user_id);

-- Users can only delete their own entries (for cleanup)
CREATE POLICY "rate_limit_logs_delete" ON public.rate_limit_logs
  FOR DELETE USING ((SELECT auth.uid()) = user_id);
