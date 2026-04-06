# OAuth Continuation Leak 修正ガイド

## 🔴 問題

```
SWIFT TASK CONTINUATION MISUSE: signInWithOAuth(provider:redirectTo:scopes:queryParams:configure:) leaked its continuation without resuming it.
```

このエラーは、Supabase Swift SDKの`signInWithOAuth`のconfigureコールバックが適切に処理されていないことを示しています。

---

## 🔍 原因

1. **configureコールバックの非同期処理**: configureコールバック内で非同期処理を行っている
2. **@MainActorとの競合**: `@MainActor`が設定されているクラスで、configureコールバックが適切に実行されていない
3. **Supabase Swift SDKの実装**: configureコールバックは同期的に実行される必要がある

---

## ✅ 修正方法

### 方法1: configureコールバックを完全に同期的にする（現在の実装）

```swift
try await supabase.auth.signInWithOAuth(
    provider: .google,
    redirectTo: URL(string: "lecsy://auth/callback")
) { [weak self] session in
    guard let self = self else { return }
    // 同期的にセッションを設定
    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = false
    session.start() // これは非同期に動作するが、configureコールバックは即座に完了する
}
```

### 方法2: Supabase Swift SDKを最新バージョンに更新

```swift
// Package.swift または XcodeのPackage Dependencies
.package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
```

最新バージョンに更新することで、continuation leakの問題が修正されている可能性があります。

### 方法3: エラーハンドリングの改善

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

**Continuation leakエラーが表示されないことを確認**

---

## 🐛 まだエラーが続く場合

### 1. Supabase Swift SDKのバージョンを確認

Xcodeで：
1. プロジェクトナビゲーターでプロジェクトを選択
2. 「Package Dependencies」タブを開く
3. `supabase-swift`のバージョンを確認
4. 最新バージョンに更新

### 2. GitHub Issuesを確認

[supabase-swift GitHub Issues](https://github.com/supabase/supabase-swift/issues)で、同様の問題が報告されているか確認

### 3. 代替実装を検討

もし問題が続く場合、以下の代替実装を検討：

```swift
// 直接URLを開く方法（Supabase Swift SDKを使わない）
func signInWithGoogle() {
    let url = URL(string: "https://[project-ref].supabase.co/auth/v1/authorize?provider=google&redirect_to=lecsy://auth/callback")!
    UIApplication.shared.open(url)
}
```

ただし、この方法は推奨されません（Supabase Swift SDKを使用する方が安全）。

---

## 📚 参考資料

- [Supabase Swift Auth Documentation](https://supabase.com/docs/reference/swift/auth-signinwithoauth)
- [Supabase Swift GitHub Repository](https://github.com/supabase/supabase-swift)
- [Apple ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)

---

## 🔄 次のステップ

1. **修正を適用**: 最新のコードを確認
2. **テスト実行**: 上記のテスト手順を実行
3. **ログ確認**: エラーが解消されているか確認
4. **動作確認**: Googleサインインが正常に動作するか確認

---

**最終更新**: 2026年1月27日
