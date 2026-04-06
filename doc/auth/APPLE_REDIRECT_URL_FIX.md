# Apple Sign In リダイレクトURL設定修正ガイド

## 🔴 エラー内容

```
invalid_request
Invalid web redirect url.
```

このエラーは、Apple Developer Console側のReturn URLとSupabase側のRedirect URLが一致していないことを示しています。

## ✅ 解決手順

### 1. Supabase側のRedirect URLを確認

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. プロジェクトを選択
3. **「Authentication」** → **「URL Configuration」** を開く
4. **「Redirect URLs」** セクションを確認

**必要なRedirect URLs:**
- `https://lecsy.vercel.app/auth/callback`（本番環境）
- `http://localhost:3020/auth/callback`（ローカル開発環境）

### 2. Apple Developer Console側のReturn URLを確認・設定

1. [Apple Developer Console](https://developer.apple.com/account) にアクセス
2. **「Certificates, Identifiers & Profiles」** → **「Identifiers」** をクリック
3. **「Services IDs」** を選択
4. `com.takumiNittono.lecsy.auth` をクリック
5. **「Sign In with Apple」** の **「Configure」** をクリック
6. **「Return URLs」** セクションを確認

**必要なReturn URLs:**
- `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`（SupabaseのコールバックURL）

**重要**: Apple Developer Console側には、**SupabaseのコールバックURL**を設定する必要があります。WebアプリのURLではなく、Supabaseの認証エンドポイントのURLです。

### 3. Return URLを追加（まだ設定されていない場合）

Apple Developer Consoleで：

1. **「+」ボタン**をクリック
2. 以下のURLを入力：
   ```
   https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback
   ```
3. **「Save」**をクリック
4. メイン画面に戻って **「Save」**をクリック

### 4. 設定の確認

#### Supabase側
- **Site URL**: `https://lecsy.vercel.app`（本番URL）
- **Redirect URLs**:
  - `https://lecsy.vercel.app/auth/callback`
  - `http://localhost:3020/auth/callback`

#### Apple Developer Console側
- **Services ID**: `com.takumiNittono.lecsy.auth`
- **Return URLs**:
  - `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`

### 5. 動作確認

設定を更新した後：

1. ブラウザのキャッシュをクリア（Cmd+Shift+R）
2. WebアプリでApple Sign Inボタンをクリック
3. Apple認証画面が表示されることを確認

## 📝 重要なポイント

### Apple Developer Console側のReturn URL

Apple Developer Console側には、**Supabaseの認証エンドポイント**を設定します：

```
https://[project-ref].supabase.co/auth/v1/callback
```

**プロジェクト参照ID**: `bjqilokchrqfxzimfnpm`

### Supabase側のRedirect URL

Supabase側には、**WebアプリのコールバックURL**を設定します：

```
https://lecsy.vercel.app/auth/callback
```

### フロー

1. ユーザーがApple Sign Inボタンをクリック
2. SupabaseがApple認証を開始（`https://appleid.apple.com/auth/...`）
3. ユーザーがApple IDで認証
4. AppleがSupabaseのコールバックURLにリダイレクト（`https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`）
5. Supabaseが認証を処理
6. SupabaseがWebアプリのコールバックURLにリダイレクト（`https://lecsy.vercel.app/auth/callback`）

## 🔍 トラブルシューティング

### 問題1: まだエラーが表示される

**確認事項**:
1. Apple Developer Console側のReturn URLが正しく保存されているか
2. Supabase側のRedirect URLが正しく設定されているか
3. ブラウザのキャッシュをクリアしたか
4. 設定変更後、数分待ってから再試行（反映に時間がかかる場合がある）

### 問題2: ローカル環境で動作しない

**解決方法**:
1. Supabase DashboardのRedirect URLsに `http://localhost:3020/auth/callback` が追加されているか確認
2. Apple Developer Console側のReturn URLは、ローカル環境用に追加する必要はありません（SupabaseのコールバックURLのみでOK）

---

**最終更新**: 2026年1月27日
