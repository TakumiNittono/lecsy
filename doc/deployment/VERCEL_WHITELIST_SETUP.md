# Vercel 環境変数設定ガイド

## 🚀 ホワイトリスト機能をVercelで有効化

ローカル環境だけでなく、本番環境（Vercel）でもホワイトリスト機能を有効化する必要があります。

## 📝 設定手順

### 1. Vercel ダッシュボードにアクセス

1. [Vercel Dashboard](https://vercel.com/dashboard) を開く
2. `lecsy` プロジェクトを選択
3. **Settings** タブをクリック
4. 左サイドバーから **Environment Variables** を選択

### 2. 環境変数を追加

以下の環境変数を追加してください：

#### `WHITELIST_EMAILS`

| フィールド | 値 |
|----------|-----|
| **Key** | `WHITELIST_EMAILS` |
| **Value** | `nittonotakumi@gmail.com` |
| **Environment** | ✅ Production, ✅ Preview, ✅ Development |

複数のメールアドレスを登録する場合はカンマ区切りで：
```
nittonotakumi@gmail.com,tester@example.com,another@example.com
```

### 3. デプロイを再実行

環境変数を追加した後、自動的に再デプロイされます。または、手動で再デプロイ：

1. **Deployments** タブをクリック
2. 最新のデプロイの右側にある「...」メニューをクリック
3. **Redeploy** を選択

## ✅ 確認方法

### ローカル環境で確認

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/web"
npm run dev
```

`http://localhost:3020/app` にアクセスして、Subscription カードが「Pro」と表示されているか確認。

### 本番環境で確認

Vercel にデプロイ後、本番URLにアクセスして確認：

1. `nittonotakumi@gmail.com` でログイン
2. ダッシュボードの Subscription カードが「Pro」と表示される
3. 「✨ Complimentary access」のラベルが表示される

## 🔧 設定されている環境変数の一覧

本番環境で必要な環境変数：

### Next.js (Vercel)

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://bjqilokchrqfxzimfnpm.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_...

# Stripe
STRIPE_SECRET_KEY=sk_live_... (本番) / sk_test_... (テスト)
STRIPE_PRICE_ID=price_...

# ホワイトリスト
WHITELIST_EMAILS=nittonotakumi@gmail.com

# App URL
NEXT_PUBLIC_APP_URL=https://your-app.vercel.app
```

### Supabase Edge Functions

```env
# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# OpenAI
OPENAI_API_KEY=sk-...

# ホワイトリスト
WHITELIST_EMAILS=nittonotakumi@gmail.com
```

## 🐛 トラブルシューティング

### ダッシュボードで「Free」と表示される

**原因**: Vercelの環境変数が設定されていない

**対策**:
1. Vercel ダッシュボードで `WHITELIST_EMAILS` が設定されているか確認
2. 再デプロイを実行
3. ブラウザのキャッシュをクリア（Cmd+Shift+R）

### AI要約が使えない

**原因**: Supabase Edge Functions の `WHITELIST_EMAILS` が設定されていない

**対策**:
```bash
supabase secrets set WHITELIST_EMAILS="nittonotakumi@gmail.com"
supabase functions deploy summarize
```

### メールアドレスを追加したい

**Vercel側**:
1. Environment Variables で `WHITELIST_EMAILS` を編集
2. カンマ区切りで追加: `email1@example.com,email2@example.com`
3. Save → 自動再デプロイ

**Supabase側**:
```bash
supabase secrets set WHITELIST_EMAILS="email1@example.com,email2@example.com"
supabase functions deploy summarize
```

## 📊 ホワイトリストユーザーの表示

ホワイトリストユーザーがログインすると、Subscription カードは以下のように表示されます：

```
┌─────────────────────────────┐
│ Subscription            ⭐ │
├─────────────────────────────┤
│ Pro                         │
│ Developer access            │
│ ✨ Complimentary access     │
└─────────────────────────────┘
```

- 「Pro」ステータス
- 「Developer access」サブテキスト
- 「✨ Complimentary access」特別ラベル
- 「Manage Subscription」ボタンは**表示されない**（課金していないため）

## 📚 関連ドキュメント

- `WHITELIST_SETUP.md` - ホワイトリスト機能の詳細
- `WHITELIST_CLI_SETUP.md` - CLI設定方法
- `SUPABASE_CLI_READY.md` - Supabase CLI全般

---

**作成日**: 2026年2月6日
**プロジェクト**: lecsy
