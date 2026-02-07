# 🚀 Supabase CLI セットアップ完了ガイド

## ✅ 作成されたスクリプト

以下の3つのスクリプトを用意しました：

### 1. `setup-secrets.sh` - 全環境変数を一括設定（推奨）

すべての環境変数（ホワイトリスト、OpenAI、Stripe）を対話形式で設定できます。

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
./setup-secrets.sh
```

### 2. `quick-whitelist.sh` - ホワイトリストだけ設定

ホワイトリストだけを素早く設定したい場合：

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
./quick-whitelist.sh
```

### 3. 手動設定 - コマンド1行で設定

スクリプトを使わずに直接設定する場合：

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
supabase secrets set WHITELIST_EMAILS="your-email@example.com,tester@example.com"
```

## 📋 設定手順（推奨フロー）

### ステップ1: ホワイトリストを設定

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
./setup-secrets.sh
```

または、ホワイトリストだけなら：

```bash
./quick-whitelist.sh
```

### ステップ2: Edge Functionを再デプロイ

```bash
supabase functions deploy summarize
```

### ステップ3: 動作確認

```bash
# 設定を確認
supabase secrets list

# ログを確認（別ターミナルで）
supabase functions logs summarize --follow
```

## 🔍 よく使うコマンド

### 環境変数の確認

```bash
supabase secrets list
```

### 特定の環境変数を設定

```bash
# ホワイトリスト
supabase secrets set WHITELIST_EMAILS="email1@example.com,email2@example.com"

# OpenAI API Key
supabase secrets set OPENAI_API_KEY="sk-..."

# Stripe設定
supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."
```

### 環境変数を削除

```bash
supabase secrets unset WHITELIST_EMAILS
```

### Edge Functionをデプロイ

```bash
# summarize だけ
supabase functions deploy summarize

# stripe-webhook だけ
supabase functions deploy stripe-webhook

# 全てのEdge Function
supabase functions deploy
```

### ログを確認

Supabase ダッシュボードでログを確認：

```bash
# ダッシュボードを開く
open https://supabase.com/dashboard/project/bjqilokchrqfxzimfnpm/functions
```

または、Edge Function の詳細ページで「Logs」タブを確認してください。

## 📝 現在の状態

✅ Supabase CLI: インストール済み（v2.75.0）
✅ プロジェクトリンク: 完了（lecsy - bjqilokchrqfxzimfnpm）
✅ スクリプト: 作成済み（実行権限付与済み）

### 現在の環境変数:
- `ALLOWED_ORIGINS` ✅
- `SUPABASE_ANON_KEY` ✅
- `SUPABASE_DB_URL` ✅
- `SUPABASE_SERVICE_ROLE_KEY` ✅
- `SUPABASE_URL` ✅
- `WHITELIST_EMAILS` ⚠️ **未設定**
- `OPENAI_API_KEY` ⚠️ **未設定**
- `STRIPE_SECRET_KEY` ⚠️ **未設定**
- `STRIPE_WEBHOOK_SECRET` ⚠️ **未設定**

## ⚡ クイックスタート（今すぐ始める）

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"

# 方法1: 対話形式で全て設定
./setup-secrets.sh

# 方法2: ホワイトリストだけ設定
./quick-whitelist.sh

# 方法3: 手動で1つずつ設定
supabase secrets set WHITELIST_EMAILS="your-email@example.com"
supabase secrets set OPENAI_API_KEY="sk-..."
supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."

# Edge Functionを再デプロイ
supabase functions deploy summarize
```

## 🐛 トラブルシューティング

### エラー: `No project linked`

```bash
supabase link --project-ref bjqilokchrqfxzimfnpm
```

### エラー: `Not logged in`

```bash
supabase login
```

### 設定が反映されない

Edge Functionを再デプロイしてください：

```bash
supabase functions deploy summarize
```

### ログで確認

Supabase ダッシュボードでログを確認：

1. [Functions ページ](https://supabase.com/dashboard/project/bjqilokchrqfxzimfnpm/functions)を開く
2. `summarize` 関数をクリック
3. 「Logs」タブを選択

ホワイトリストユーザーがログインすると以下のログが表示されます：

```
[Whitelisted user] your-email@example.com - skipping Pro check
```

## 📚 関連ドキュメント

- `WHITELIST_CLI_SETUP.md` - 詳細なCLI設定ガイド
- `WHITELIST_SETUP.md` - ホワイトリスト機能の説明
- `STRIPE_IMPLEMENTATION_GUIDE.md` - 課金実装ガイド

---

**作成日**: 2026年2月6日
**プロジェクト**: lecsy (bjqilokchrqfxzimfnpm)
