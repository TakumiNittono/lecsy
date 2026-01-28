# Apple Sign In Capability設定ガイド

## 🔴 エラー内容

```
Authorization failed: Error Domain=AKAuthenticationError Code=-7026
ASAuthorizationController credential request failed with error: Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1000
```

このエラーは、Xcodeプロジェクトで**Sign In with Apple**のCapabilityが有効になっていないことが原因です。

## ✅ 解決手順

### 1. Xcodeでプロジェクトを開く

```bash
open lecsy.xcodeproj
```

### 2. Sign In with Apple Capabilityを有効化

1. **プロジェクトナビゲーター**でプロジェクト（青いアイコン）を選択
2. **Target「lecsy」**を選択
3. **「Signing & Capabilities」タブ**を開く
4. **「+ Capability」ボタン**をクリック
5. **「Sign In with Apple」**を検索して追加

### 3. Bundle IDの確認

現在のBundle ID: `com.takumiNittono.word.lecsy`

**確認事項**:
- Apple Developer Consoleで作成したApp IDが `com.takumiNittono.lecsy` の場合、Bundle IDを変更する必要があります
- または、Apple Developer Consoleで `com.takumiNittono.word.lecsy` のApp IDを作成し、Sign In with Appleを有効化する必要があります

### 4. Bundle IDを変更する場合（推奨）

1. **「Signing & Capabilities」タブ**で**「Bundle Identifier」**を確認
2. `com.takumiNittono.word.lecsy` → `com.takumiNittono.lecsy` に変更
3. **「Automatically manage signing」**が有効になっていることを確認
4. **「Team」**が正しく選択されていることを確認

### 5. Apple Developer ConsoleでApp IDを確認

1. [Apple Developer Console](https://developer.apple.com/account) にアクセス
2. **「Certificates, Identifiers & Profiles」** → **「Identifiers」** → **「App IDs」** を開く
3. `com.takumiNittono.lecsy` または `com.takumiNittono.word.lecsy` が存在するか確認
4. 存在するApp IDで**「Sign In with Apple」**が有効になっているか確認

### 6. App IDでSign In with Appleを有効化（まだの場合）

1. App IDを選択
2. **「Sign In with Apple」**にチェックを入れる
3. **「Configure」**をクリック
4. **「Enable as a primary App ID」**を選択
5. **「Save」**をクリック
6. メイン画面に戻って**「Save」**をクリック

## 📝 重要なポイント

### Bundle IDの一致

- **XcodeプロジェクトのBundle ID** = **Apple Developer ConsoleのApp ID**
- これらが一致していないと、Sign In with Appleが動作しません

### Capabilityの有効化

- Xcodeプロジェクトで**Sign In with Apple**のCapabilityを追加する必要があります
- これがないと、`ASAuthorizationController`が正しく動作しません

## 🔍 トラブルシューティング

### 問題1: Capabilityを追加できない

**原因**: Bundle IDがApple Developer Consoleに登録されていない

**解決方法**:
1. Apple Developer ConsoleでApp IDを作成
2. Sign In with Appleを有効化
3. XcodeでCapabilityを追加

### 問題2: Bundle IDを変更したらビルドエラー

**解決方法**:
1. **「Clean Build Folder」**を実行（Shift + Cmd + K）
2. プロジェクトを再ビルド
3. 必要に応じて、依存関係を再インストール

### 問題3: まだエラーが表示される

**確認事項**:
1. Sign In with AppleのCapabilityが追加されているか
2. Bundle IDが正しいか
3. Apple Developer ConsoleでApp IDのSign In with Appleが有効になっているか
4. プロジェクトをクリーンビルドしたか

---

**最終更新**: 2026年1月27日
