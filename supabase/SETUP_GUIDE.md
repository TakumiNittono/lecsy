# Supabase & Stripe セットアップガイド

このガイドでは、SupabaseとStripeの実装を順番に進めます。

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
supabase functions deploy stripe-webhook
```

#### 2-3. 環境変数設定

```bash
# OpenAI API Key（summarize関数用）
supabase secrets set OPENAI_API_KEY=your_openai_api_key_here --project-ref your_project_ref

# Stripe Keys（stripe-webhook関数用）
# 後でStripe設定後に設定
supabase secrets set STRIPE_SECRET_KEY=sk_live_... --project-ref bjqilokchrqfxzimfnpm
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_... --project-ref bjqilokchrqfxzimfnpm
```

**注意:** Stripe Keysは後で設定します。

### Step 3: Stripe 設定

#### 3-1. Stripe アカウント作成・ログイン

1. [Stripe Dashboard](https://dashboard.stripe.com) にアクセス
2. アカウントを作成（またはログイン）
3. **テストモード** で開始（本番前に切り替え）

#### 3-2. 商品・価格作成

1. Stripe Dashboard > **Products** を開く
2. **Add product** をクリック
3. 以下の設定を入力：
   - **Name**: `lecsy Pro`
   - **Description**: `AI要約・Exam Mode機能付きProプラン`
   - **Pricing model**: `Standard pricing`
   - **Price**: `$2.99`
   - **Billing period**: `Monthly`
   - **Recurring**: ✅ チェック
4. **Save product** をクリック
5. **Price ID** をコピー（`price_xxx` 形式）

#### 3-3. Webhook設定

1. Stripe Dashboard > **Developers** > **Webhooks** を開く
2. **Add endpoint** をクリック
3. **Endpoint URL** に以下を入力：
   ```
   https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/stripe-webhook
   ```
4. **Events to send** で以下を選択：
   - `checkout.session.completed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_failed`
5. **Add endpoint** をクリック
6. **Signing secret** をコピー（`whsec_xxx` 形式）

#### 3-4. API Keys取得

1. Stripe Dashboard > **Developers** > **API keys** を開く
2. **Publishable key** をコピー（`pk_test_xxx` または `pk_live_xxx`）
3. **Secret key** をコピー（`sk_test_xxx` または `sk_live_xxx`）
   - **Reveal test key** をクリックして表示

### Step 4: 環境変数設定

#### 4-1. Supabase Edge Functions にStripe Keys設定

```bash
cd supabase

# Stripe Secret Key
supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx --project-ref bjqilokchrqfxzimfnpm

# Stripe Webhook Secret
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx --project-ref bjqilokchrqfxzimfnpm
```

#### 4-2. Webアプリの環境変数設定

1. `web/.env.local` ファイルを作成
2. 以下の内容を設定：

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://bjqilokchrqfxzimfnpm.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxx
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PRICE_ID=price_xxx
NEXT_PUBLIC_APP_URL=http://localhost:3020
```

### Step 5: WebアプリにStripe連携API追加

Webアプリに以下のAPIルートを追加：
- `/api/create-checkout-session` - Checkout Session作成
- `/api/create-portal-session` - Customer Portal作成

（実装は次のステップで行います）

## ✅ 確認チェックリスト

### Supabase
- [ ] データベーススキーマ適用完了
- [ ] Edge Functions デプロイ完了
- [ ] 環境変数設定完了（OpenAI, Stripe）

### Stripe
- [ ] 商品・価格作成完了
- [ ] Webhook設定完了
- [ ] API Keys取得完了

### Webアプリ
- [ ] 環境変数設定完了（`.env.local`）
- [ ] Stripe APIルート実装完了

## 🔗 参考リンク

- [Supabase Dashboard](https://app.supabase.com)
- [Stripe Dashboard](https://dashboard.stripe.com)
- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Stripe Checkout Docs](https://stripe.com/docs/payments/checkout)
