# Apple OAuth Secret Key 設定ガイド

## 🔴 現在の問題

Supabase DashboardのApple認証設定で、**「Secret Key (for OAuth)」が設定されていません**。
これが原因で、Web側のApple Sign Inボタンが動作していません。

## ✅ 解決手順

### 1. Apple Developer Consoleでキーを作成

1. [Apple Developer Console](https://developer.apple.com/account) にアクセス
2. **「Certificates, Identifiers & Profiles」** をクリック
3. 左サイドバーから **「Keys」** を選択
4. 右上の **「+」ボタン** をクリック
5. キー名を入力（例: `Lecsy Sign In with Apple Key`）
6. **「Sign In with Apple」** にチェックを入れる
7. **「Configure」** をクリック
8. **「Primary App ID」** を選択（`com.takumiNittono.lecsy`）
9. **「Save」** をクリック
10. **「Continue」** → **「Register」** をクリック
11. **「Download」** をクリックして `.p8` ファイルをダウンロード（**この機会にしかダウンロードできません**）
12. **「Key ID」** をメモ（例: `ABC123DEF4`）

### 2. Team IDを確認

1. Apple Developer Consoleの右上のアカウント名をクリック
2. **Team ID** を確認（例: `XYZ9ABCDEF`）

### 3. Secret Keyを生成

Apple OAuth用のSecret Key（JWT）を生成する必要があります。

**推奨方法: プロジェクトに用意されているNode.jsスクリプトを使用**

プロジェクトルートに`generate-apple-secret.js`スクリプトを用意しています：

```bash
# 1. 必要なパッケージをインストール
cd web
npm install jsonwebtoken

# 2. プロジェクトルートに戻る
cd ..

# 3. スクリプトを実行
node generate-apple-secret.js
```

スクリプトが対話形式で以下を聞いてきます：
- **Team ID**: Apple Developer Consoleの右上から取得
- **Key ID**: ステップ1で作成したキーのID
- **Services ID**: デフォルトは `com.takumiNittono.lecsy.auth`（そのままEnterでOK）
- **.p8ファイルのパス**: ダウンロードした`.p8`ファイルのパス（例: `./AuthKey_XXXXXXXXXX.p8`）

スクリプトがSecret Key（JWT）を生成して表示します。この文字列をコピーしてください。

**注意**: Supabase CLIにはApple OAuth Secret Keyを生成する直接コマンドはありません。このスクリプトを使用してください。

### 4. Supabase Dashboardに設定

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. プロジェクトを選択
3. **「Authentication」** → **「Providers」** をクリック
4. **「Apple」** をクリック
5. **「Secret Key (for OAuth)」** フィールドに、ステップ3で生成したJWTを貼り付け
6. **「Save」** をクリック

### 5. 動作確認

1. WebアプリでApple Sign Inボタンをクリック
2. Apple認証画面が表示されることを確認
3. 認証が完了すると、コールバックURLにリダイレクトされることを確認

## 📝 必要な情報まとめ

設定に必要な情報：

- **Team ID**: Apple Developer Consoleの右上から取得
- **Key ID**: ステップ1で作成したキーのID
- **Private Key**: `.p8` ファイル（ダウンロードしたもの）
- **Services ID**: `com.takumiNittono.lecsy.auth`（既に設定済み）
- **Client IDs**: `com.takumiNittono.lecsy.auth`（既に設定済み）

## ⚠️ 重要な注意事項

1. **Secret Keyは6ヶ月ごとに期限切れになります**
   - 期限切れの1ヶ月前には新しいキーを生成して更新してください
   - 期限切れになると、Web側のApple Sign Inが動作しなくなります

2. **`.p8`ファイルは一度しかダウンロードできません**
   - 安全な場所に保存してください
   - 紛失した場合は、新しいキーを作成する必要があります

3. **iOS側のネイティブサインインは影響を受けません**
   - Secret KeyはWeb側のOAuthフローのみに必要です
   - iOS側はネイティブのApple Sign Inを使用しているため、Secret Keyは不要です

## 🔍 トラブルシューティング

### 問題1: Secret Keyを生成できない

**原因**: `jsonwebtoken`パッケージがインストールされていない、または`.p8`ファイルのパスが間違っている

**解決方法**:
```bash
npm install jsonwebtoken
# .p8ファイルのパスを確認
ls -la AuthKey_*.p8
```

### 問題2: Secret Keyを設定しても動作しない

**確認事項**:
1. Secret Keyが正しくコピーされているか（改行やスペースが含まれていないか）
2. Team ID、Key ID、Services IDが正しいか
3. `.p8`ファイルが正しいキーに対応しているか

### 問題3: 6ヶ月後に期限切れになる

**解決方法**:
- カレンダーにリマインダーを設定
- 期限切れの1ヶ月前に新しいSecret Keyを生成
- Supabase Dashboardで更新

---

**最終更新**: 2026年1月27日
