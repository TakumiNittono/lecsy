# Supabase セットアップガイド

このガイドでは、Supabaseの実装を順番に進めます。
**Stripe連携は後回し**にします。

## 📋 セットアップ手順

### Step 1: Supabase データベーススキーマ適用

1. [Supabase Dashboard](https://app.supabase.com) にアクセス
2. プロジェクトを選択（`bjqilokchrqfxzimfnpm`）
3. **SQL Editor** を開く
4. `migrations/001_initial_schema.sql` の内容をコピー
5. SQL Editor に貼り付けて **Run** をクリック
6. 成功メッセージを確認

**確認方法:**
- Table Editor で以下のテーブルが作成されているか確認：
  - `transcripts`
  - `summaries`
  - `subscriptions`
  - `usage_logs`

**確認SQL:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('transcripts', 'summaries', 'subscriptions', 'usage_logs');
```

### Step 2: Supabase Edge Functions デプロイ

#### 2-1. プロジェクトリンク

```bash
cd supabase
supabase link --project-ref bjqilokchrqfxzimfnpm
```

#### 2-2. Functions デプロイ

```bash
# 各関数をデプロイ
supabase functions deploy save-transcript
supabase functions deploy summarize
# stripe-webhook は後回し
# supabase functions deploy stripe-webhook
```

#### 2-3. 環境変数設定

```bash
# OpenAI API Key（summarize関数用）
supabase secrets set OPENAI_API_KEY=your_openai_api_key_here --project-ref your_project_ref

# Stripe Keysは後回し
# supabase secrets set STRIPE_SECRET_KEY=sk_live_... --project-ref bjqilokchrqfxzimfnpm
# supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_... --project-ref bjqilokchrqfxzimfnpm
```

### Step 3: 認証設定（オプション）

#### 3-1. Google OAuth 設定（後で実装時）

1. [Google Cloud Console](https://console.cloud.google.com) で設定
2. Supabase Dashboard > Authentication > Providers > Google で設定

#### 3-2. Apple Sign In 設定（後で実装時）

1. [Apple Developer Console](https://developer.apple.com/account) で設定
2. Supabase Dashboard > Authentication > Providers > Apple で設定

#### 3-3. Redirect URLs 設定

Supabase Dashboard > Authentication > URL Configuration で以下を設定：

- **Site URL**: `http://localhost:3020` (開発用)
- **Redirect URLs**:
  - `lecsy://auth/callback` (iOS)
  - `http://localhost:3020/auth/callback` (Web開発用)

### Step 4: Webアプリ環境変数設定

1. `web/.env.local` ファイルを作成
2. 以下の内容を設定：

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://bjqilokchrqfxzimfnpm.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH

# Stripe（後回し）
# NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxx
# STRIPE_SECRET_KEY=sk_test_xxx
# STRIPE_PRICE_ID=price_xxx

NEXT_PUBLIC_APP_URL=http://localhost:3020
```

### Step 5: 動作確認

#### 5-1. データベース確認

Supabase Dashboard > Table Editor でテーブルが作成されているか確認

#### 5-2. Edge Functions 確認

Supabase Dashboard > Edge Functions で以下がデプロイされているか確認：
- `save-transcript`
- `summarize`

#### 5-3. API動作確認

```bash
# save-transcript テスト（認証トークンが必要）
curl -X POST https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/save-transcript \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Transcript",
    "content": "This is a test transcript.",
    "created_at": "2026-01-27T00:00:00Z"
  }'
```

## ✅ 確認チェックリスト

### Supabase
- [ ] データベーススキーマ適用完了
- [ ] Edge Functions デプロイ完了（save-transcript, summarize）
- [ ] 環境変数設定完了（OpenAI API Key）
- [ ] テーブル作成確認（transcripts, summaries, subscriptions, usage_logs）
- [ ] RLSポリシー確認

### Webアプリ
- [ ] 環境変数設定完了（`.env.local`）
- [ ] Supabaseクライアント設定確認

### 後回し（Stripe）
- [ ] Stripe商品・価格作成
- [ ] Stripe Webhook設定
- [ ] Stripe Edge Functionデプロイ
- [ ] Stripe APIルート実装（既に作成済み）

## 🔗 参考リンク

- [Supabase Dashboard](https://app.supabase.com)
- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)

## 📝 次のステップ

Supabaseの実装が完了したら、Phase 1のiOS/Webアプリ実装に進みます。
