# Supabase 設定確認ガイド

このファイルは、Supabase設定が正しく完了しているかを確認するためのチェックリストです。

## 🔍 設定確認手順

### 1. Supabase プロジェクト確認

#### プロジェクト情報の確認

1. [Supabase Dashboard](https://app.supabase.com) にアクセス
2. プロジェクト一覧で `lecsy` プロジェクトを確認
3. プロジェクト設定を確認：
   - **Project URL**: `https://[project-ref].supabase.co`
   - **Region**: `Northeast Asia (Tokyo)`
   - **Database Password**: 保存済みか確認

#### プロジェクト参照IDの取得

1. Supabase Dashboard > Settings > General
2. **Reference ID** をコピー（例: `abcdefghijklmnop`）
3. このIDを `.env` ファイルやコマンドで使用

### 2. データベース設定確認

#### テーブル確認

Supabase Dashboard > Table Editor で以下が存在するか確認：

- [ ] `transcripts` テーブル
- [ ] `summaries` テーブル
- [ ] `subscriptions` テーブル
- [ ] `usage_logs` テーブル

#### RLS確認

Supabase Dashboard > Authentication > Policies で各テーブルのRLSが有効か確認：

- [ ] `transcripts` - RLS有効、4つのポリシー（SELECT, INSERT, UPDATE, DELETE）
- [ ] `summaries` - RLS有効、3つのポリシー（SELECT, INSERT, UPDATE）
- [ ] `subscriptions` - RLS有効、1つのポリシー（SELECT）
- [ ] `usage_logs` - RLS有効、1つのポリシー（SELECT）

#### インデックス確認

Supabase Dashboard > Database > Indexes で以下が存在するか確認：

**transcripts:**
- [ ] `idx_transcripts_user_id`
- [ ] `idx_transcripts_created_at`
- [ ] `idx_transcripts_user_created`

**summaries:**
- [ ] `idx_summaries_transcript_id`
- [ ] `idx_summaries_user_id`

**subscriptions:**
- [ ] `idx_subscriptions_status`
- [ ] `idx_subscriptions_stripe_customer`

**usage_logs:**
- [ ] `idx_usage_logs_user_created`
- [ ] `idx_usage_logs_user_action_created`

### 3. 認証設定確認

#### Google OAuth 確認

Supabase Dashboard > Authentication > Providers > Google:

- [ ] Google プロバイダーが有効化されている
- [ ] Client ID が設定されている
- [ ] Client Secret が設定されている
- [ ] Google Cloud Console でリダイレクトURIが設定されている

**確認方法:**
```bash
# Google Cloud Console で確認
# 承認済みのリダイレクト URI に以下が含まれているか確認
https://[project-ref].supabase.co/auth/v1/callback
```

#### Apple Sign In 確認

Supabase Dashboard > Authentication > Providers > Apple:

- [ ] Apple プロバイダーが有効化されている
- [ ] Services ID が設定されている（`com.takumiNittono.lecsy.auth`）
- [ ] Team ID が設定されている
- [ ] Key ID が設定されている
- [ ] Private Key が設定されている

**確認方法:**
- Apple Developer Console > Identifiers > Services IDs で確認
- Return URL に以下が設定されているか確認：
  ```
  https://[project-ref].supabase.co/auth/v1/callback
  ```

#### Redirect URLs 確認

Supabase Dashboard > Authentication > URL Configuration:

- [ ] **Site URL**: `https://lecsy.app` または開発用URL
- [ ] **Redirect URLs** に以下が含まれている：
  - [ ] `lecsy://auth/callback` (iOS)
  - [ ] `https://lecsy.app/auth/callback` (Web)
  - [ ] `http://localhost:3000/auth/callback` (ローカル開発)

### 4. Edge Functions 確認

#### Functions デプロイ確認

Supabase Dashboard > Edge Functions で以下がデプロイされているか確認：

- [ ] `save-transcript`
- [ ] `summarize`
- [ ] `stripe-webhook`

#### 環境変数確認

Supabase Dashboard > Edge Functions > 各関数の設定で以下が設定されているか確認：

**save-transcript:**
- [ ] `SUPABASE_URL` (自動設定)
- [ ] `SUPABASE_ANON_KEY` (自動設定)

**summarize:**
- [ ] `SUPABASE_URL` (自動設定)
- [ ] `SUPABASE_ANON_KEY` (自動設定)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` (手動設定)
- [ ] `OPENAI_API_KEY` (手動設定)

**stripe-webhook:**
- [ ] `SUPABASE_URL` (自動設定)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` (手動設定)
- [ ] `STRIPE_SECRET_KEY` (手動設定)
- [ ] `STRIPE_WEBHOOK_SECRET` (手動設定)

**確認コマンド:**
```bash
# CLIで確認
supabase secrets list --project-ref your-project-ref
```

### 5. 動作確認

#### 認証フロー確認

1. **テストユーザー作成:**
   - Supabase Dashboard > Authentication > Users
   - 「Add user」でテストユーザーを作成

2. **OAuth ログインテスト:**
   - Webアプリから Google/Apple ログインを試す
   - リダイレクトが正常に動作するか確認

#### API動作確認

**save-transcript テスト:**
```bash
# 認証トークンを取得してから
curl -X POST https://[project-ref].supabase.co/functions/v1/save-transcript \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Transcript",
    "content": "This is a test transcript.",
    "created_at": "2026-01-27T00:00:00Z"
  }'
```

**summarize テスト:**
```bash
# Proユーザーでテスト
curl -X POST https://[project-ref].supabase.co/functions/v1/summarize \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transcript_id": "uuid-here",
    "mode": "summary"
  }'
```

## 🐛 よくある問題と解決方法

### 問題1: RLSポリシーでアクセス拒否される

**原因:** RLSポリシーが正しく設定されていない、または認証トークンが無効

**解決方法:**
1. Supabase Dashboard > Authentication > Policies でポリシーを確認
2. 認証トークンが有効か確認
3. `auth.uid()` が正しく取得できているか確認

### 問題2: Edge Function で環境変数が取得できない

**原因:** 環境変数が設定されていない、または関数に設定されていない

**解決方法:**
```bash
# 環境変数を設定
supabase secrets set KEY_NAME=value --project-ref your-project-ref

# 設定を確認
supabase secrets list --project-ref your-project-ref
```

### 問題3: OAuth リダイレクトエラー

**原因:** Redirect URL が正しく設定されていない

**解決方法:**
1. Supabase Dashboard > Authentication > URL Configuration を確認
2. Google Cloud Console / Apple Developer Console のリダイレクトURIを確認
3. 完全一致しているか確認（スラッシュの有無など）

### 問題4: データベース接続エラー

**原因:** データベースパスワードが間違っている、または接続情報が間違っている

**解決方法:**
1. Supabase Dashboard > Settings > Database で接続情報を確認
2. `.env` ファイルの `SUPABASE_URL` が正しいか確認

## 📝 確認完了チェックリスト

- [ ] Supabase プロジェクト作成完了
- [ ] データベーススキーマ適用完了（テーブル、RLS、インデックス）
- [ ] Google OAuth 設定完了
- [ ] Apple Sign In 設定完了
- [ ] Redirect URLs 設定完了
- [ ] Edge Functions デプロイ完了
- [ ] 環境変数設定完了
- [ ] 認証フロー動作確認（テストログイン）
- [ ] API動作確認（save-transcript, summarize）

## 🔗 次のステップ

すべてのチェックが完了したら、Phase 1 の実装に進みます：
- [実装ロードマップ](../doc/07_実装ロードマップ.md) の Phase 1 を参照
