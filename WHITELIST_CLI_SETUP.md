# Supabase CLI でホワイトリストを設定する方法

## 🚀 クイック設定（推奨）

### 方法1: インタラクティブスクリプトを使う

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
./setup-whitelist.sh
```

メールアドレスを入力するだけで自動設定されます。

### 方法2: コマンド1行で設定

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
supabase secrets set WHITELIST_EMAILS="your-email@example.com,tester@example.com"
```

**注意**: メールアドレスは実際のものに置き換えてください。

## 📋 完全な設定手順

### 1. Supabase にログイン

```bash
supabase login
```

ブラウザが開くので、Supabaseアカウントでログインしてください。

### 2. プロジェクトにリンク

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
supabase link --project-ref bjqilokchrqfxzimfnpm
```

### 3. ホワイトリストを設定

```bash
supabase secrets set WHITELIST_EMAILS="your-email@example.com,tester@example.com"
```

### 4. Edge Function を再デプロイ

```bash
supabase functions deploy summarize
```

### 5. 設定を確認

```bash
supabase secrets list
```

`WHITELIST_EMAILS` が表示されていればOKです。

## 🔍 現在の設定を確認

```bash
supabase secrets list
```

## ✏️ ホワイトリストを更新

追加のメールアドレスを設定する場合も同じコマンドを使います：

```bash
supabase secrets set WHITELIST_EMAILS="email1@example.com,email2@example.com,email3@example.com"
```

**注意**: 既存の値は上書きされるので、すべてのメールアドレスを含めてください。

## 🗑️ ホワイトリストを削除

```bash
supabase secrets unset WHITELIST_EMAILS
```

## 📝 その他の必要な環境変数

ホワイトリスト以外にも、以下の環境変数が必要です：

```bash
# OpenAI API Key（AI要約用）
supabase secrets set OPENAI_API_KEY="sk-..."

# Stripe設定（課金用）
supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."
```

一度に複数設定する場合：

```bash
supabase secrets set \
  WHITELIST_EMAILS="your-email@example.com,tester@example.com" \
  OPENAI_API_KEY="sk-..." \
  STRIPE_SECRET_KEY="sk_test_..." \
  STRIPE_WEBHOOK_SECRET="whsec_..."
```

## 🐛 トラブルシューティング

### `supabase: command not found`

Supabase CLIがインストールされていません：

```bash
brew install supabase/tap/supabase
```

### `No project linked`

プロジェクトにリンクされていません：

```bash
supabase link --project-ref bjqilokchrqfxzimfnpm
```

### 設定が反映されない

Edge Functionを再デプロイしてください：

```bash
supabase functions deploy summarize
```

### 値を確認したい

セキュリティ上、値は表示されませんが、設定されているかは確認できます：

```bash
supabase secrets list
```

## 📚 参考リンク

- [Supabase CLI ドキュメント](https://supabase.com/docs/reference/cli)
- [Edge Functions Secrets](https://supabase.com/docs/guides/functions/secrets)

---

**作成日**: 2026年2月6日
