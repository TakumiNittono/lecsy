# 環境変数設定ガイド

**作成日**: 2026年2月6日

このガイドでは、Stripe課金機能をテストするために必要な環境変数の設定方法を説明します。

---

## 📋 必要な環境変数

### 1. Next.js Web アプリ（`.env.local`）

**ファイル**: `web/.env.local`

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key

# Stripe (テスト環境)
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxx
STRIPE_PRICE_ID=price_xxxxxxxxxxxxx

# App URL
NEXT_PUBLIC_APP_URL=http://localhost:3020
```

**取得方法**:
- `STRIPE_SECRET_KEY`: [Stripe ダッシュボード](https://dashboard.stripe.com/test/apikeys) → **API keys** → **Secret key** をコピー
- `STRIPE_PRICE_ID`: Stripe ダッシュボード → **Products** → Product作成 → Price IDをコピー

---

### 2. Supabase Edge Functions（Supabase ダッシュボード）

**場所**: Supabase ダッシュボード → **Edge Functions** → **Secrets**

以下の環境変数を追加：

```env
# Stripe
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx

# OpenAI (AI要約機能用)
OPENAI_API_KEY=sk-xxxxxxxxxxxxx
```

**取得方法**:

#### `STRIPE_SECRET_KEY`
- [Stripe ダッシュボード](https://dashboard.stripe.com/test/apikeys) → **API keys** → **Secret key** をコピー
- Next.js と同じ値を使用

#### `STRIPE_WEBHOOK_SECRET`
1. **Stripe CLI をインストール**:
   ```bash
   brew install stripe/stripe-cli/stripe
   ```

2. **Stripe CLI にログイン**:
   ```bash
   stripe login
   ```

3. **Webhook をローカルに転送**（テスト用）:
   ```bash
   stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook
   ```
   
   または、**Supabase の本番URLに転送**（Preview環境テスト時）:
   ```bash
   stripe listen --forward-to https://<PROJECT_REF>.supabase.co/functions/v1/stripe-webhook
   ```

4. **Webhook Signing Secret をコピー**:
   コマンド実行後、以下のような出力が表示されます：
   ```
   > Ready! Your webhook signing secret is whsec_xxxxxxxxxxxxx
   ```
   この `whsec_xxxxxxxxxxxxx` をコピーして、Supabase の `STRIPE_WEBHOOK_SECRET` に設定してください。

#### `OPENAI_API_KEY`
- [OpenAI Platform](https://platform.openai.com/api-keys) → **API keys** → **Create new secret key**
- テスト用でも実際のAPIキーを使用（無料枠があれば使用可能）

---

## ✅ 設定確認チェックリスト

### Next.js (`.env.local`)
- [ ] `NEXT_PUBLIC_SUPABASE_URL` が設定されている
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` が設定されている
- [ ] `STRIPE_SECRET_KEY` が `sk_test_` で始まる（テスト環境）
- [ ] `STRIPE_PRICE_ID` が `price_` で始まる
- [ ] `NEXT_PUBLIC_APP_URL` が正しい（ローカル: `http://localhost:3020`）

### Supabase Edge Functions
- [ ] `STRIPE_SECRET_KEY` が設定されている（Next.jsと同じ値）
- [ ] `STRIPE_WEBHOOK_SECRET` が `whsec_` で始まる（Stripe CLIで取得）
- [ ] `OPENAI_API_KEY` が設定されている（AI要約機能用）

---

## 🧪 テスト前の確認

環境変数を設定したら、以下を確認してください：

1. **Next.js サーバーを再起動**:
   ```bash
   cd web
   npm run dev
   ```

2. **Supabase Edge Functions がデプロイされているか確認**:
   ```bash
   supabase functions deploy stripe-webhook
   ```

3. **Stripe CLI で Webhook を転送**:
   ```bash
   stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook
   ```

---

## ⚠️ 注意事項

### セキュリティ

- ✅ `.env.local` は **gitignore** に含まれていることを確認
- ✅ 本番環境では **Vercel** と **Supabase** の環境変数設定を使用
- ❌ 環境変数をコードに直接書かない
- ❌ 環境変数をGitにコミットしない

### テスト環境 vs 本番環境

| 環境 | Stripe Key | 用途 |
|------|-----------|------|
| **テスト** | `sk_test_xxx` | ローカル開発・Preview環境 |
| **本番** | `sk_live_xxx` | 本番環境（Vercel/Supabase） |

---

## 🔗 関連ドキュメント

- [Stripe テストカード一覧](https://stripe.com/docs/testing)
- [Stripe CLI ドキュメント](https://stripe.com/docs/stripe-cli)
- [Supabase Edge Functions 環境変数](https://supabase.com/docs/guides/functions/secrets)

---

**最終更新**: 2026年2月6日
