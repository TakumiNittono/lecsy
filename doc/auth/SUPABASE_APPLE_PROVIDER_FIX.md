# Supabase Apple Provider 設定修正ガイド

## 🚨 問題: 認証に問題がある

「AppleのプロバイダーをSupabaseダッシュボードで調べろ」と言われた場合、以下の手順で設定を確認・修正してください。

---

## 📋 確認手順（必須）

### Step 1: Supabase Dashboard にアクセス

1. [Supabase Dashboard](https://app.supabase.com) にログイン
2. プロジェクト `bjqilokchrqfxzimfnpm` を選択

### Step 2: Apple Provider 設定を確認

**Authentication > Providers > Apple** を開いて、以下を確認してください：

#### ✅ 必須設定項目

| 項目 | 設定値 | 確認方法 |
|------|--------|----------|
| **Enable Sign in with Apple** | ✅ **ON（有効）** | トグルスイッチがONになっているか |
| **Client ID (Services ID)** | `com.takumiNittono.lecsy.auth` | テキストフィールドに正しく入力されているか |
| **Team ID** | `G7LG228243` | テキストフィールドに正しく入力されているか |
| **Key ID** | `5HH2THJXAY`（または作成したKey ID） | テキストフィールドに正しく入力されているか |
| **Secret Key (for OAuth)** | JWT形式の長い文字列 | **空欄ではないか**、有効なJWTが設定されているか |

---

## 🔧 よくある問題と解決方法

### 問題1: Enable Sign in with Apple が無効になっている

**症状**: 認証が全く動作しない

**解決方法**:
1. Supabase Dashboard > Authentication > Providers > Apple を開く
2. 「Enable Sign in with Apple」のトグルスイッチを **ON** にする
3. 「Save」をクリック

---

### 問題2: Secret Key が空欄または期限切れ

**症状**: `Invalid client secret` エラーが発生

**解決方法**:

#### 2-1. Secret Key を再生成

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
node generate-apple-secret.js
```

**入力値**:
- Team ID: `G7LG228243`
- Key ID: `5HH2THJXAY`（または作成したKey ID）
- Services ID: `com.takumiNittono.lecsy.auth`（Enterキーでデフォルト値を使用）
- .p8ファイルのパス: `/Users/takuminittono/Desktop/AuthKey_5HH2THJXAY.p8`（実際のパスに合わせて変更）

#### 2-2. 生成されたJWTをSupabase Dashboardに貼り付け

1. スクリプトが出力した長いJWT文字列をコピー
2. Supabase Dashboard > Authentication > Providers > Apple を開く
3. 「Secret Key (for OAuth)」フィールドに貼り付け
4. 「Save」をクリック

**注意**: Secret Keyは6ヶ月ごとに期限切れになります。期限切れの1ヶ月前に更新してください。

---

### 問題3: Client ID (Services ID) が間違っている

**症状**: `Invalid client` エラーが発生

**解決方法**:
1. Supabase Dashboard > Authentication > Providers > Apple を開く
2. 「Client ID (Services ID)」フィールドを確認
3. 正しい値: `com.takumiNittono.lecsy.auth`
4. 間違っている場合は修正して「Save」をクリック

---

### 問題4: Team ID が間違っている

**症状**: 認証が失敗する

**解決方法**:
1. Supabase Dashboard > Authentication > Providers > Apple を開く
2. 「Team ID」フィールドを確認
3. 正しい値: `G7LG228243`
4. 間違っている場合は修正して「Save」をクリック

---

### 問題5: Key ID が間違っている

**症状**: Secret Keyが無効と判定される

**解決方法**:
1. Apple Developer Console > Certificates, Identifiers & Profiles > Keys を開く
2. Sign In with Apple用のキーを確認
3. Key IDをコピー（例: `5HH2THJXAY`）
4. Supabase Dashboard > Authentication > Providers > Apple を開く
5. 「Key ID」フィールドに貼り付け
6. 「Save」をクリック

---

## 🔍 設定確認チェックリスト

以下のチェックリストを順番に確認してください：

- [ ] Supabase Dashboard > Authentication > Providers > Apple を開いた
- [ ] 「Enable Sign in with Apple」が **ON** になっている
- [ ] 「Client ID (Services ID)」に `com.takumiNittono.lecsy.auth` が設定されている
- [ ] 「Team ID」に `G7LG228243` が設定されている
- [ ] 「Key ID」に正しいKey IDが設定されている
- [ ] 「Secret Key (for OAuth)」にJWT形式の文字列が設定されている（空欄ではない）
- [ ] 「Save」をクリックした

---

## 🧪 動作確認方法

### iOSアプリで確認

1. Xcodeでアプリをビルド・実行
2. ログイン画面で「Sign in with Apple」をタップ
3. コンソールログを確認：
   - ✅ 成功: `✅ AuthService: Appleサインイン成功`
   - ❌ 失敗: エラーメッセージが表示される

### エラーログの確認

Xcodeのコンソールで以下のようなエラーが表示された場合：

```
❌ AuthService: Appleサインイン処理エラー
   - Error: ...
   - HTTP Status Code: 401
```

→ **Supabase Dashboardで設定を確認してください**

---

## 📝 Apple Developer Console 側の確認

Supabaseの設定を確認した後、Apple Developer Console側も確認してください：

### 1. Services ID の確認

1. [Apple Developer Console](https://developer.apple.com/account) にアクセス
2. **Certificates, Identifiers & Profiles** > **Identifiers** を開く
3. **Services IDs** を選択
4. `com.takumiNittono.lecsy.auth` が存在するか確認
5. 「Sign In with Apple」が有効になっているか確認
6. 「Configure」をクリックして、**Return URLs** に以下が設定されているか確認：
   ```
   https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback
   ```

### 2. Key の確認

1. **Keys** を選択
2. Sign In with Apple用のキーが存在するか確認
3. Key IDをメモ（Supabase Dashboardの設定と一致しているか確認）

---

## 🚀 設定が完了したら

1. **Supabase Dashboardで「Save」をクリック**
2. **数秒待つ**（設定が反映されるまで）
3. **iOSアプリを再起動**
4. **Sign in with Appleを再度試す**

---

## 📞 まだ問題が解決しない場合

以下の情報を確認してください：

1. **Xcodeコンソールのエラーログ**をコピー
2. **Supabase Dashboardの設定スクリーンショット**を撮影
3. **Apple Developer Consoleの設定**を確認

エラーメッセージの内容によって、具体的な解決方法が異なります。

---

## 🔗 参考リンク

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Apple Sign In with Supabase](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Apple Developer Console](https://developer.apple.com/account)

---

**最終更新**: 2026年1月30日
