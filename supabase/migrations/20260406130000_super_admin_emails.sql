-- super_admin_emails: Edge Functions の requireSuperAdmin() が参照するテーブル
-- (supabase/functions/_shared/auth.ts より)
-- このテーブルが無いと全 super admin Edge Function が 403 を返す

CREATE TABLE IF NOT EXISTS super_admin_emails (
    email TEXT PRIMARY KEY,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE super_admin_emails ENABLE ROW LEVEL SECURITY;

-- 通常ユーザーから一切アクセス不可。service_role のみ (RLS バイパス) が読み書きする想定。
-- (ポリシーを 1 個も作らない = 全ての非 service_role アクセスは拒否)

-- 初期 super admin を seed
INSERT INTO super_admin_emails (email, note)
VALUES ('nittonotakumi@gmail.com', 'initial owner / dev')
ON CONFLICT (email) DO NOTHING;
