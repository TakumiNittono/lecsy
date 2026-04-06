# Edge Function JWT検証エラー 解決ガイド

## 🔴 現在の問題

- `execution_id`が`null` → Edge Functionが実行されていない
- すべての呼び出しが401エラー
- Logsタブに「No results found」

これは、**SupabaseのAPI GatewayレベルでJWT検証が失敗**している可能性が高いです。

---

## 🔍 確認手順

### ステップ1: Invocationsタブでリクエストヘッダーを確認

1. **Invocationsタブ**で、401エラーの呼び出しをクリック
2. 詳細パネルの「**Raw**」タブを開く
3. リクエストヘッダーを確認：
   - `Authorization: Bearer eyJhbGciOiJFUzI1NiIs...` が含まれているか
   - ヘッダーが正しく送信されているか

### ステップ2: Edge Functionの設定を確認

Supabase Dashboardで：
1. **Edge Functions** > **save-transcript** > **Details**タブ
2. JWT検証の設定を確認

---

## ✅ 解決方法

### 方法1: Edge Function内でJWT検証を手動実装（推奨）

現在の実装では、Edge Function内でJWT検証を行っていますが、API GatewayレベルでJWT検証が失敗している可能性があります。

**対応**: Edge Functionの設定でJWT検証を無効にするか、またはJWT検証をバイパスする方法を検討します。

### 方法2: JWT検証を無効にする（開発環境のみ）

**注意**: 本番環境では推奨されません。

Edge Functionの設定でJWT検証を無効にするには、Supabase Dashboardで：
1. **Edge Functions** > **save-transcript** > **Details**タブ
2. 「**Verify JWT**」を無効にする

### 方法3: JWTトークンの形式を確認

アプリ側で送信されているJWTトークンが正しい形式か確認：

```swift
// SyncService.swift
print("🌐 SyncService: アクセストークン取得 - \(accessToken.prefix(20))...")
print("🌐 SyncService: トークン長: \(accessToken.count) characters")
print("🌐 SyncService: Authorizationヘッダー設定 - Bearer \(accessToken.prefix(30))...")
```

---

## 🐛 考えられる原因

### 原因1: JWTトークンが無効または期限切れ

**確認方法**:
- Invocationsタブの「Raw」タブでリクエストヘッダーを確認
- JWTトークンの有効期限を確認

**解決方法**:
- セッションをリフレッシュ（既に実装済み）
- トークンの有効期限を確認

### 原因2: API GatewayレベルでJWT検証が失敗

**確認方法**:
- `execution_id`が`null` → Edge Functionが実行されていない
- Logsタブに「No results found」 → 関数内の`console.log`が実行されていない

**解決方法**:
- Edge Functionの設定でJWT検証を無効にする
- または、JWTトークンが正しく送信されているか確認

### 原因3: JWTトークンの形式が間違っている

**確認方法**:
- `Authorization: Bearer <token>`の形式になっているか
- Bearerプレフィックスが正しく追加されているか

**解決方法**:
- アプリ側でBearerプレフィックスを確認（既に実装済み）

---

## 🔧 次のステップ

1. **Invocationsタブの「Raw」タブでリクエストヘッダーを確認**
   - `Authorization`ヘッダーが含まれているか
   - ヘッダーの形式が正しいか

2. **Edge Functionの設定を確認**
   - JWT検証が有効になっているか
   - 必要に応じてJWT検証を無効にする

3. **ログの内容を共有**
   - リクエストヘッダーの内容
   - エラーメッセージの詳細

---

**最終更新**: 2026年1月27日
