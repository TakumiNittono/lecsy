# 環境変数設定ガイド

## 1. Next.js Web アプリ（`web/.env.local`）

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key

# Stripe（テスト環境）
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxx
STRIPE_PRICE_ID=price_xxxxxxxxxxxxx
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxxx

# App URL
NEXT_PUBLIC_APP_URL=http://localhost:3020

# ホワイトリスト（開発者用Pro無料アクセス）
WHITELIST_EMAILS=nittonotakumi@gmail.com
```

**取得方法**:
- `STRIPE_SECRET_KEY`: [Stripe ダッシュボード](https://dashboard.stripe.com/test/apikeys) > API keys > Secret key
- `STRIPE_PRICE_ID`: Stripe ダッシュボード > Products > Product作成 > Price ID

---

## 2. Supabase Edge Functions（Supabase ダッシュボード > Edge Functions > Secrets）

```env
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxx
WHITELIST_EMAILS=nittonotakumi@gmail.com
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app
```

### Stripe Webhook Secret の取得

```bash
brew install stripe/stripe-cli/stripe
stripe login
stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook
# 表示される whsec_xxxxxxxxxxxxx をコピー
```

### ALLOWED_ORIGINS（CORS制御）

```env
# 本番環境
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app

# 開発環境
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:54323

# 本番 + 開発
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app,http://localhost:3000
```

**注意**: カンマ区切り、スペースなし、プロトコル必須、末尾スラッシュなし

設定変更後は Edge Functions の再デプロイが必要:
```bash
supabase functions deploy save-transcript
supabase functions deploy summarize
```

---

## 3. Vercel（Vercel ダッシュボード > Settings > Environment Variables）

Vercel にも同じ環境変数を設定:
- `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_APP_URL` (本番URL)
- `WHITELIST_EMAILS`

---

## 4. Supabase CLI で一括設定

```bash
supabase secrets set \
  WHITELIST_EMAILS="nittonotakumi@gmail.com" \
  OPENAI_API_KEY="sk-..." \
  STRIPE_SECRET_KEY="sk_test_..." \
  STRIPE_WEBHOOK_SECRET="whsec_..." \
  ALLOWED_ORIGINS="https://lecsy.vercel.app,https://www.lecsy.app"
```

確認: `supabase secrets list`

---

## セキュリティ注意事項

- `.env.local` は `.gitignore` に含まれていることを確認
- 本番環境では Vercel / Supabase の環境変数設定を使用
- 環境変数をコードに直接書かない・Gitにコミットしない

| 環境 | Stripe Key | 用途 |
|------|-----------|------|
| テスト | `sk_test_xxx` | ローカル開発・Preview環境 |
| 本番 | `sk_live_xxx` | 本番環境（Vercel/Supabase） |
