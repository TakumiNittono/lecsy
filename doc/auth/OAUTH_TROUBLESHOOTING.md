# OAuth認証 トラブルシューティングガイド

## 🔴 現在の問題

### Continuation Leak エラー

```
SWIFT TASK CONTINUATION MISUSE: signInWithOAuth(provider:redirectTo:scopes:queryParams:configure:) leaked its continuation without resuming it.
```

このエラーは、Supabase Swift SDKの`signInWithOAuth`のconfigureコールバックが適切に処理されていないことを示しています。

---

## 🔍 原因分析

### 問題の根本原因

1. **configureコールバックの非同期処理**: configureコールバック内で`Task { @MainActor in ... }`を使用しているため、continuationが適切にresumeされていない

2. **Supabase Swift SDKの期待動作**: `signInWithOAuth`のconfigureコールバックは**同期的に実行される**必要がある

3. **OAuthフローの非同期性**: OAuthフロー自体は非同期に進行するが、configureコールバックは即座に完了する必要がある

---

## ✅ 解決方法

### 方法1: configureコールバックを同期的に実行（推奨）

```swift
try await supabase.auth.signInWithOAuth(
    provider: .google,
    redirectTo: URL(string: "lecsy://auth/callback")
) { session in
    // 同期的にセッションを設定
    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = false
    session.start() // これは非同期に動作するが、configureコールバックは即座に完了する
}
```

### 方法2: エラーハンドリングの改善

OAuthフローのエラーは`authStateChanges`で監視する：

```swift
case .signedIn:
    isLoading = false
    errorMessage = nil
    await checkSession()
```

---

## 🧪 テスト手順

### 1. クリーンビルド

```bash
# Xcodeで
Product > Clean Build Folder (Shift + Cmd + K)
```

### 2. アプリを再実行

```bash
Product > Run (Cmd + R)
```

### 3. Googleサインインをテスト

1. 設定画面で「Sign In」をタップ
2. 「Sign in with Google」をタップ
3. ブラウザでGoogleログインを完了
4. アプリに戻る
5. ログイン状態が更新されることを確認

### 4. ログを確認

以下のログが表示されることを確認：

```
🔐 AuthService: Googleサインイン開始
🔐 AuthService: Google OAuthセッション開始完了
🔗 lecsyApp: URL受信 - lecsy://auth/callback?...
🔗 lecsyApp: 認証コールバックURLを処理
🔐 AuthService: サインイン成功 - Event: signedIn
✅ AuthService: セッション確認成功 - User ID: ...
```

---

## 🐛 よくある問題と解決方法

### 問題1: Continuation Leakが続く

**原因**: configureコールバック内で非同期処理を行っている

**解決方法**:
- configureコールバックを同期的に実行する
- `Task { @MainActor in ... }`を使用しない

### 問題2: サインイン後もログイン状態が更新されない

**原因**: `authStateChanges`が正しく監視されていない

**解決方法**:
- `lecsyApp.swift`の`onOpenURL`でセッションを確認
- `authStateChanges`の`.signedIn`イベントを確認

### 問題3: ブラウザが開かない

**原因**: URL Schemeが正しく設定されていない

**解決方法**:
- `Info.plist`で`CFBundleURLTypes`を確認
- Scheme: `lecsy`が設定されているか確認

### 問題4: コールバックURLが処理されない

**原因**: `onOpenURL`が正しく実装されていない

**解決方法**:
- `lecsyApp.swift`の`onOpenURL`を確認
- URLのパースが正しいか確認

---

## 📚 参考資料

- [Supabase Swift Auth Documentation](https://supabase.com/docs/reference/swift/auth-signinwithoauth)
- [Apple ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)

---

## 🔄 次のステップ

1. **修正を適用**: 最新のコードを確認
2. **テスト実行**: 上記のテスト手順を実行
3. **ログ確認**: エラーが解消されているか確認
4. **動作確認**: Googleサインインが正常に動作するか確認

---

**最終更新**: 2026年1月27日
