# Web版 Google/Apple ログイン問題 調査結果と解決方法

## 問題の概要

**症状**: Web版でGoogle/Appleログインができない（iPhoneでは正常に動作する）

**調査日**: 2026年2月1日

---

## ドメイン構成

| 種類 | ドメイン | 用途 |
|------|----------|------|
| **メインドメイン** | `www.lecsy.app` | 本番環境（Vercelに設定済み） |
| Vercelデフォルト | `lecsy.vercel.app` | Vercel自動生成（使用しない） |

---

## 調査結果

### 1. OAuth認証画面は正常に表示される

ブラウザで確認したところ、以下の点は正常に動作しています：

- ✅ ログインボタンクリック → Google/Apple認証画面へリダイレクト
- ✅ Supabase anon keyは正常に機能（OAuthフローが開始される）
- ✅ クライアントIDは正しく設定されている

### 2. 根本原因: Supabase DashboardのSite URL設定が間違っている

OAuth stateパラメータのJWTをデコードした結果、以下の問題が発見されました：

```json
{
  "site_url": "   https://www.lecsy.app",   // ← 先頭に3つのスペース
  "referrer": "   https://www.lecsy.app",   // ← 同様の問題
  "provider": "google",
  "flow_state_id": "cb56ea91-c9ce-4027-893e-566564df23c4"
}
```

**問題点**:
- **Site URLの先頭に余分なスペース（3つ）** が含まれている
- スペースのせいでリダイレクトが正常に動作しない

### 3. iPhoneで動作する理由

iOSアプリでは、カスタムURLスキーム `lecsy://auth/callback` を使用しており、OAuthコールバック処理がSite URL設定に依存しません。そのため、Site URLの設定が間違っていてもiOSでは正常に動作します。

---

## 解決方法

### 手順1: Supabase DashboardでSite URLを修正

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. プロジェクト `bjqilokchrqfxzimfnpm` を選択
3. **Authentication** → **URL Configuration** を開く
4. **Site URL** を確認・修正

**現在の設定（間違い）**:
```
   https://www.lecsy.app
```
（先頭に3つのスペースがある）

**正しい設定**:
```
https://www.lecsy.app
```
（スペースなし、メインドメインを使用）

### 手順2: Redirect URLsを確認・追加

同じ **URL Configuration** ページで、**Redirect URLs** セクションに以下が含まれているか確認：

| 環境 | Redirect URL |
|------|--------------|
| **本番環境（メイン）** | `https://www.lecsy.app/auth/callback` |
| Vercelデフォルト | `https://lecsy.vercel.app/auth/callback` |
| 開発環境 | `http://localhost:3020/auth/callback` |
| iOS | `lecsy://auth/callback` |

**重要**: 4つすべてのURLを追加してください。

### 手順3: 変更を保存して再テスト

1. **Save** ボタンをクリック
2. ブラウザのキャッシュをクリア（Cmd+Shift+R または Ctrl+Shift+R）
3. Web版でログインを再テスト

---

## 設定確認チェックリスト

### Supabase Dashboard（Authentication → URL Configuration）

- [ ] **Site URL** が `https://www.lecsy.app` になっている（スペースなし）
- [ ] **Redirect URLs** に `https://www.lecsy.app/auth/callback` が含まれている
- [ ] **Redirect URLs** に `https://lecsy.vercel.app/auth/callback` が含まれている
- [ ] **Redirect URLs** に `http://localhost:3020/auth/callback` が含まれている（開発用）
- [ ] **Redirect URLs** に `lecsy://auth/callback` が含まれている（iOS用）

### Google Cloud Console（OAuth設定）

- [ ] **Authorized redirect URIs** に `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback` が含まれている

### Apple Developer Console（Sign In with Apple設定）

- [ ] **Return URLs** に `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback` が含まれている

---

## 技術的な詳細

### OAuth認証フロー（Web版）

```
1. ユーザーがログインボタンをクリック
   ↓
2. Supabaseが認証URLを生成（stateパラメータにsite_urlを含む）
   ↓
3. Google/Apple認証画面にリダイレクト
   ↓
4. ユーザーが認証を完了
   ↓
5. Google/AppleがSupabaseコールバックにリダイレクト
   （https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback）
   ↓
6. SupabaseがWebアプリのコールバックにリダイレクト  ← ここで問題発生
   （site_urlの設定が間違っているため、正しくリダイレクトされない）
   ↓
7. Webアプリがセッションを確立
```

### stateパラメータのJWT構造

```json
{
  "exp": 1769971571,
  "site_url": "https://www.lecsy.app",  // ← ここが正しく設定される必要がある
  "id": "00000000-0000-0000-0000-000000000000",
  "function_hooks": null,
  "provider": "google",
  "referrer": "https://www.lecsy.app",
  "flow_state_id": "cb56ea91-c9ce-4027-893e-566564df23c4"
}
```

---

## トラブルシューティング

### 問題1: 設定を修正してもログインできない

**確認事項**:
1. ブラウザのキャッシュを完全にクリアしたか
2. 設定変更後、数分待ってから再試行（反映に時間がかかる場合がある）
3. シークレットモード/プライベートブラウジングで試す

### 問題2: 「Invalid redirect」エラーが表示される

**原因**: Redirect URLsに正しいURLが追加されていない

**解決方法**:
1. Supabase Dashboard → Authentication → URL Configuration
2. Redirect URLsに以下を追加:
   - `https://www.lecsy.app/auth/callback`
   - `https://lecsy.vercel.app/auth/callback`
3. 保存して再試行

### 問題3: ローカル開発環境でログインできない

**確認事項**:
1. Redirect URLsに `http://localhost:3020/auth/callback` が含まれているか
2. `.env.local` の `NEXT_PUBLIC_APP_URL` が `http://localhost:3020` になっているか

---

## 関連ファイル

| ファイル | 説明 |
|---------|------|
| `web/app/login/page.tsx` | ログインページのUIとOAuth処理 |
| `web/app/auth/callback/route.ts` | OAuthコールバック処理 |
| `web/utils/supabase/client.ts` | Supabaseクライアント設定 |
| `web/.env.local` | 環境変数設定 |

---

## Vercel環境変数の設定

Vercelの本番環境では、以下の環境変数が正しく設定されている必要があります：

| 変数名 | 値 |
|--------|-----|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://bjqilokchrqfxzimfnpm.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | （現在の値を使用） |

**注意**: `NEXT_PUBLIC_APP_URL`は不要です。コードでは`window.location.origin`を使用しているため、ドメインに応じて自動的に正しいURLが生成されます。

---

## 参考リンク

- [Supabase Dashboard](https://supabase.com/dashboard)
- [Supabase Auth Configuration](https://supabase.com/docs/guides/auth/redirect-urls)
- [OAuth 2.0 Flow](https://oauth.net/2/)

---

**最終更新**: 2026年2月1日
