# Apple Sign In デバッグガイド

## 🔍 問題の確認手順

### 1. ブラウザのコンソールを確認

1. Webアプリを開く（http://localhost:3020/login または本番URL）
2. **F12** または **Cmd+Option+I** で開発者ツールを開く
3. **Console**タブを開く
4. Apple Sign Inボタンをクリック
5. コンソールに表示されるログを確認

**期待されるログ:**
```
🍎 Apple Sign In button clicked
🍎 Starting Apple OAuth flow...
🍎 Supabase client created
🍎 OAuth response: { data: {...}, error: null }
🍎 Redirecting to: https://...
```

**エラーの場合:**
- `🍎 OAuth error: ...` が表示される
- エラーメッセージをコピーして確認

### 2. Supabase Dashboardで設定を確認

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. プロジェクトを選択
3. **「Authentication」** → **「Providers」** → **「Apple」** を開く
4. 以下を確認：
   - ✅ **Enable Sign in with Apple** が有効になっている
   - ✅ **Client IDs** に `com.takumiNittono.lecsy.auth` が設定されている
   - ✅ **Secret Key (for OAuth)** にJWTが設定されている（空欄ではない）
   - ✅ **Callback URL** が正しく設定されている

### 3. Secret Keyを再生成（必要に応じて）

もしSecret Keyに問題がある場合、再生成してください：

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
node generate-apple-secret.js
```

**入力値（コピー&ペースト）:**
- Team ID: `G7LG228243`
- Key ID: `5HH2THJXAY`
- Services ID: `com.takumiNittono.lecsy.auth`（またはEnterキー）
- .p8ファイルのパス: `/Users/takuminittono/Desktop/AuthKey_5HH2THJXAY.p8`

### 4. よくあるエラーと解決方法

#### エラー1: "Invalid client secret"
**原因**: Secret Keyが正しく設定されていない、または期限切れ

**解決方法**:
1. Secret Keyを再生成
2. Supabase Dashboardで更新
3. ブラウザのキャッシュをクリア（Cmd+Shift+R）

#### エラー2: "redirect_uri_mismatch"
**原因**: Callback URLが正しく設定されていない

**解決方法**:
1. Supabase Dashboard > Authentication > URL Configuration を確認
2. Redirect URLsに以下が含まれているか確認：
   - `http://localhost:3020/auth/callback`（開発環境）
   - `https://lecsy.vercel.app/auth/callback`（本番環境）

#### エラー3: "The operation couldn't be completed"
**原因**: Apple Developer Console側の設定が不完全

**解決方法**:
1. Apple Developer Console > Identifiers > Services IDs を確認
2. `com.takumiNittono.lecsy.auth` が存在するか確認
3. Sign In with Appleが有効になっているか確認
4. Return URLに以下が設定されているか確認：
   - `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`

### 5. ネットワークタブで確認

1. 開発者ツールの **Network**タブを開く
2. Apple Sign Inボタンをクリック
3. `authorize` または `callback` というリクエストを探す
4. リクエストのステータスコードを確認：
   - **200**: 正常
   - **400**: リクエストエラー（設定を確認）
   - **401**: 認証エラー（Secret Keyを確認）
   - **500**: サーバーエラー（Supabase側の問題）

## 📝 チェックリスト

- [ ] ブラウザのコンソールにエラーがない
- [ ] Supabase DashboardでApple認証が有効になっている
- [ ] Secret Keyが設定されている（空欄ではない）
- [ ] Client IDsが正しく設定されている
- [ ] Callback URLが正しく設定されている
- [ ] Apple Developer Console側の設定が完了している
- [ ] ブラウザのキャッシュをクリアした

---

**最終更新**: 2026年1月27日
