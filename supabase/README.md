# Supabase 設定ガイド

このディレクトリには、lecsy プロジェクトの Supabase 設定ファイルが含まれています。

## 📁 ディレクトリ構造

```
supabase/
├── migrations/          # データベースマイグレーション
│   └── 001_initial_schema.sql
├── functions/           # Edge Functions
│   ├── save-transcript/
│   ├── summarize/
│   └── stripe-webhook/
├── config.toml          # ローカル開発設定
├── .env.example         # 環境変数テンプレート
└── README.md           # このファイル
```

## 🚀 Phase 0 セットアップ手順

### 1. Supabase プロジェクト作成

1. [Supabase Dashboard](https://app.supabase.com) にアクセス
2. 「New Project」をクリック
3. 以下の設定を入力：
   - **Organization**: 既存の組織を選択（なければ作成）
   - **Name**: `lecsy`
   - **Database Password**: 強力なパスワードを生成・保存
   - **Region**: `Northeast Asia (Tokyo)` を選択
   - **Pricing Plan**: Free プランで開始（本番前に Pro に移行）

### 2. データベース設定

1. Supabase Dashboard > SQL Editor を開く
2. `migrations/001_initial_schema.sql` の内容をコピー
3. SQL Editor に貼り付けて実行
4. テーブル、RLS、インデックス、トリガーが作成されることを確認

### 3. 認証設定

#### Google OAuth 設定

1. **Google Cloud Console 設定**:
   - [Google Cloud Console](https://console.cloud.google.com) にアクセス
   - プロジェクトを作成（または既存を選択）
   - 「APIとサービス」>「認証情報」に移動
   - 「OAuth同意画面」を設定（外部ユーザー向け）
   - 「認証情報を作成」>「OAuth 2.0 クライアントID」を作成
   - アプリケーションの種類: `ウェブアプリケーション`
   - 承認済みのリダイレクト URI に追加:
     ```
     https://[project-ref].supabase.co/auth/v1/callback
     ```
   - Client ID と Client Secret をコピー

2. **Supabase 設定**:
   - Supabase Dashboard > Authentication > Providers
   - Google を有効化
   - Client ID と Client Secret を入力
   - 「Save」をクリック

#### Apple Sign In 設定

1. **Apple Developer Console 設定**:
   - [Apple Developer Console](https://developer.apple.com/account) にアクセス
   - 「Certificates, Identifiers & Profiles」>「Identifiers」
   - 「Services IDs」で新規作成
   - Identifier: `com.takumiNittono.lecsy.auth`
   - 「Sign In with Apple」を有効化
   - 「Configure」をクリック
   - Return URL に追加:
     ```
     https://[project-ref].supabase.co/auth/v1/callback
     ```
   - 「Keys」>「Sign In with Apple」用のキーを作成
   - Key ID と Private Key をダウンロード・保存

2. **Supabase 設定**:
   - Supabase Dashboard > Authentication > Providers
   - Apple を有効化
   - Services ID、Team ID、Key ID、Private Key を入力
   - 「Save」をクリック

#### Redirect URLs 設定

Supabase Dashboard > Authentication > URL Configuration で以下を設定：

- **Site URL**: `https://lecsy.app` (本番URL)
- **Redirect URLs**:
  - `lecsy://auth/callback` (iOS)
  - `https://lecsy.app/auth/callback` (Web)
  - `http://localhost:3000/auth/callback` (ローカル開発)

### 4. Edge Functions デプロイ

#### Supabase CLI インストール

```bash
# macOS
brew install supabase/tap/supabase

# または npm
npm install -g supabase
```

#### ログイン

```bash
supabase login
```

#### プロジェクトリンク

```bash
supabase link --project-ref your-project-ref
```

#### 環境変数設定

1. `.env.example` をコピーして `.env` を作成
2. Supabase Dashboard > Settings > API から以下を取得：
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. `.env` に値を設定

#### Functions デプロイ

```bash
# すべての関数をデプロイ
supabase functions deploy save-transcript
supabase functions deploy summarize
supabase functions deploy stripe-webhook

# または一括デプロイ（すべての関数）
cd functions
for dir in */; do
  supabase functions deploy "${dir%/}"
done
```

#### 環境変数を Functions に設定

```bash
# 各関数に環境変数を設定
supabase secrets set OPENAI_API_KEY=sk-... --project-ref your-project-ref
supabase secrets set STRIPE_SECRET_KEY=sk_live_... --project-ref your-project-ref
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_... --project-ref your-project-ref
```

### 5. ローカル開発環境（オプション）

#### Supabase CLI でローカル起動

```bash
# ローカル Supabase を起動
supabase start

# マイグレーションを適用
supabase db reset

# ローカル Functions を実行
supabase functions serve save-transcript --env-file .env
```

## ✅ 確認チェックリスト

- [ ] Supabase プロジェクト作成完了
- [ ] データベーススキーマ適用完了（テーブル、RLS、インデックス）
- [ ] Google OAuth 設定完了
- [ ] Apple Sign In 設定完了
- [ ] Redirect URLs 設定完了
- [ ] Edge Functions デプロイ完了
- [ ] 環境変数設定完了
- [ ] 認証フロー動作確認（テストログイン）

## 🔗 参考リンク

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Auth Guide](https://supabase.com/docs/guides/auth)
- [Edge Functions Guide](https://supabase.com/docs/guides/functions)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)

## 📝 次のステップ

Phase 0 が完了したら、[実装ロードマップ](../doc/07_実装ロードマップ.md) の Phase 1 に進みます。
