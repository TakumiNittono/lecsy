# Vercel デプロイガイド — Stripe 課金テスト

**作成日**: 2026年2月6日

---

## 📋 前提条件

- [x] Stripe CLI インストール済み
- [x] Stripe CLI ログイン済み
- [x] Supabase Edge Functions デプロイ済み
- [x] Webhook Secret 取得済み

---

## 🚀 Vercel デプロイ手順

### Step 1: Vercel プロジェクトの確認

1. [Vercel ダッシュボード](https://vercel.com/dashboard) にログイン
2. 既存のプロジェクトがあるか確認
   - プロジェクト名: `lecsy` または類似
   - ルートディレクトリ: `web`

### Step 2: 環境変数の設定（重要）

Vercel ダッシュボード → プロジェクト → **Settings** → **Environment Variables** に以下を追加：

#### Production / Preview / Development すべてに設定

| キー | 値 | 説明 |
|------|-----|------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://your-project.supabase.co` | Supabase URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `your_anon_key` | Supabase Anon Key |
| `STRIPE_SECRET_KEY` | `sk_test_xxxxxxxxxxxxx` | Stripe Secret Key（テスト、Stripe ダッシュボードから取得） |
| `STRIPE_PRICE_ID` | `price_xxxxxxxxxxxxx` | Stripe Price ID |
| `NEXT_PUBLIC_APP_URL` | `https://your-project.vercel.app` | Vercel デプロイURL |

**重要**: 環境変数を追加したら、**再デプロイが必要**です。

### Step 3: デプロイ方法

#### 方法1: GitHub連携（推奨）

1. GitHub リポジトリを Vercel に接続
2. 自動デプロイが有効になっている場合、`git push` で自動デプロイ
3. または、Vercel ダッシュボード → **Deployments** → **Redeploy**

#### 方法2: Vercel CLI

```bash
# Vercel CLI をインストール（未インストールの場合）
npm i -g vercel

# プロジェクトルートで実行
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"

# デプロイ
vercel

# または、プロダクション環境にデプロイ
vercel --prod
```

**注意**: Vercel CLI を使用する場合、ルートディレクトリを `web` に設定する必要があります。

### Step 4: Supabase の環境変数を設定

Supabase ダッシュボード → **Edge Functions** → **Secrets** に以下を設定：

| キー | 値 |
|------|-----|
| `STRIPE_SECRET_KEY` | `sk_test_xxxxxxxxxxxxx` （Stripe ダッシュボードから取得） |
| `STRIPE_WEBHOOK_SECRET` | `whsec_xxxxxxxxxxxxx` （Stripe CLI または Stripe ダッシュボードから取得） |
| `OPENAI_API_KEY` | `sk-xxx` （オプション） |

---

## 🔗 Webhook の設定

### Vercel デプロイ後の Webhook URL

Vercel にデプロイしたら、Supabase Edge Function の Webhook URL は：

```
https://your-project-ref.supabase.co/functions/v1/stripe-webhook
```

### Stripe CLI で Webhook を転送（テスト用）

Vercel にデプロイ後、以下のコマンドで Webhook を転送：

```bash
stripe listen --forward-to https://your-project-ref.supabase.co/functions/v1/stripe-webhook
```

**注意**: このコマンドはローカル開発用です。本番環境では、Stripe ダッシュボードで Webhook エンドポイントを登録してください。

### Stripe ダッシュボードで Webhook を登録（本番用）

1. [Stripe ダッシュボード](https://dashboard.stripe.com/test/webhooks) → **Developers** → **Webhooks**
2. **Add endpoint** をクリック
3. 以下を設定：

| 項目 | 値 |
|------|-----|
| **Endpoint URL** | `https://your-project-ref.supabase.co/functions/v1/stripe-webhook` |
| **Events to listen** | `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed` |

4. 作成後、**Signing secret** をコピー（`whsec_xxx`）
5. この Signing secret を Supabase の環境変数 `STRIPE_WEBHOOK_SECRET` に設定

---

## 🧪 テストフロー

### Step 1: Vercel にデプロイ

```bash
# 方法1: GitHub経由（自動）
git add .
git commit -m "Add Stripe payment integration"
git push

# 方法2: Vercel CLI
vercel --prod
```

### Step 2: デプロイURLを確認

Vercel ダッシュボード → **Deployments** → 最新のデプロイのURLを確認
例: `https://lecsy.vercel.app`

### Step 3: 環境変数を確認

Vercel ダッシュボード → **Settings** → **Environment Variables** で以下を確認：
- ✅ `STRIPE_SECRET_KEY` が設定されている
- ✅ `STRIPE_PRICE_ID` が設定されている
- ✅ `NEXT_PUBLIC_APP_URL` が正しい（Vercel URL）

### Step 4: Webhook を設定

**オプションA: Stripe CLI でテスト（推奨）**

```bash
stripe listen --forward-to https://your-project-ref.supabase.co/functions/v1/stripe-webhook
```

**オプションB: Stripe ダッシュボードで登録（本番用）**

上記の「Stripe ダッシュボードで Webhook を登録」を参照

### Step 5: テストフローを実行

1. **ブラウザで** Vercel URL（例: `https://lecsy.vercel.app`）にアクセス
2. **ログイン** → `/login` でGoogle/Apple Sign In
3. **ダッシュボード** (`/app`) に移動
4. **"Upgrade to Pro — $2.99/mo"** ボタンをクリック
5. **Stripe Checkout ページ**が開く
6. **テストカード**を入力：
   - カード番号: `4242 4242 4242 4242`
   - 有効期限: `12/34`
   - CVC: `123`
   - 郵便番号: `12345`
7. **"Subscribe"** をクリック
8. **成功** → `/app?success=true` にリダイレクト
9. **トースト通知**が表示される
10. **Subscription カード**が "Pro" に変わる

---

## ✅ チェックリスト

デプロイ前：

- [ ] Vercel の環境変数が設定されている
- [ ] Supabase の環境変数が設定されている
- [ ] `NEXT_PUBLIC_APP_URL` が正しい（Vercel URL）

デプロイ後：

- [ ] Vercel にデプロイが成功している
- [ ] Webhook が設定されている（Stripe CLI または Stripe ダッシュボード）
- [ ] テストフローが動作する

---

## 🔍 トラブルシューティング

### デプロイが失敗する

- **原因**: ビルドエラー
- **対策**: Vercel ダッシュボード → **Deployments** → エラーログを確認

### 環境変数が読み込まれない

- **原因**: 再デプロイしていない
- **対策**: 環境変数を追加したら、**Redeploy** を実行

### Webhook が届かない

- **原因**: Webhook URL が間違っている
- **対策**: Supabase Edge Function のURLを確認

### Checkout Session 作成に失敗する

- **原因**: `STRIPE_SECRET_KEY` または `STRIPE_PRICE_ID` が未設定
- **対策**: Vercel の環境変数を確認

---

## 📝 次のステップ

1. **Vercel にデプロイ**
2. **環境変数を設定**
3. **Webhook を設定**（Stripe CLI または Stripe ダッシュボード）
4. **テストフローを実行**

---

**最終更新**: 2026年2月6日
