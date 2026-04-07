-- B2B 整理: dead schema を全部削る + plan を free/pro の 2 値に統一
--
-- 削除対象 (アプリコード参照ゼロを確認済):
--   - org_classes / org_class_members      (将来機能、未実装)
--   - org_glossary                         (org_glossaries の重複作成事故)
--   - org_billing_profiles                 (Stripe 同期の中間テーブル、未使用)
--   - org_invoices / org_seat_snapshots    (enterprise 機能、未実装)
--   - org_sso_configs / org_scim_tokens    (enterprise 機能、未実装)
--   - org_security_policies                (enterprise 機能、未実装)
--   - data_deletion_requests               (未実装)
--
-- 残すテーブル (実装済 + 実際に使われている):
--   - organizations / organization_members  (コア)
--   - org_glossaries                        (用語集、Edge Function + Web で使用)
--   - org_ai_usage_logs                     (利用量集計)
--   - audit_logs                            (監査)
--   - super_admin_emails                    (Edge Function 認可)
--
-- plan 簡素化:
--   - free   = 何も払ってない (lecsy 内部試用 / 無料トライアル)
--   - pro    = 学校が払って全機能アンロック
--   (starter/growth/business/enterprise は廃止)

-- ============================================
-- 1. plan 値の正規化
-- ============================================
-- 既存の CHECK を外してから値を書き換え、新しい CHECK を貼る順序が必須
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_plan_check;

UPDATE organizations
SET plan = 'pro'
WHERE plan NOT IN ('free', 'pro');

ALTER TABLE organizations
  ADD CONSTRAINT organizations_plan_check
  CHECK (plan IN ('free', 'pro'));

-- デフォルトを 'pro' に (新規作成は基本有料)
ALTER TABLE organizations ALTER COLUMN plan SET DEFAULT 'pro';

-- ============================================
-- 2. dead テーブルを削除
-- ============================================
-- Drop in dependency order. Use CASCADE to nuke any leftover policies/triggers.

DROP TABLE IF EXISTS data_deletion_requests CASCADE;
DROP TABLE IF EXISTS org_security_policies CASCADE;
DROP TABLE IF EXISTS org_scim_tokens CASCADE;
DROP TABLE IF EXISTS org_sso_configs CASCADE;
DROP TABLE IF EXISTS org_seat_snapshots CASCADE;
DROP TABLE IF EXISTS org_invoices CASCADE;
DROP TABLE IF EXISTS org_billing_profiles CASCADE;
DROP TABLE IF EXISTS org_glossary CASCADE;          -- 重複事故テーブル
DROP TABLE IF EXISTS org_class_members CASCADE;
DROP TABLE IF EXISTS org_classes CASCADE;

-- ============================================
-- 3. 不要になった列を削除 (transcripts.class_id が org_classes 参照)
-- ============================================
ALTER TABLE transcripts DROP COLUMN IF EXISTS class_id;

-- visibility は class/org_wide のうち class 用途が消えるが、enum 値はそのまま残しても害ないので touch しない
-- (transcripts に既存データがあるので CHECK 変更は破壊的)
