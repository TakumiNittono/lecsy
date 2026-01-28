# Edge Function 401エラー デバッグガイド

## 🔴 現在の状況

- アプリから`save-transcript` Edge Functionを呼び出している
- 401エラーが発生している
- しかし、`edge_logs`にログが記録されていない

これは、**API Gatewayレベルで401エラーが返されている**可能性が高いです。

---

## 🔍 確認手順

### 1. Edge FunctionのInvocationsタブを確認

Supabase Dashboard > **Edge Functions** > **save-transcript** > **Invocations**タブを開く：

1. 左サイドバーで「**Edge Functions**」をクリック
2. 「**save-transcript**」をクリック
3. 「**Invocations**」タブを開く
4. 最近の呼び出しを確認
   - 401エラーが表示されているか
   - リクエストの詳細を確認

### 2. より広い範囲でログを検索

**Logs & Analytics**で以下のクエリを試してください：

```sql
-- すべてのEdge Function呼び出しを確認
SELECT 
  timestamp,
  event_message,
  metadata
FROM edge_logs
WHERE 
  event_message LIKE '%functions/v1/%'
ORDER BY timestamp DESC
LIMIT 50
```

### 3. API Gatewayのログを確認

```sql
-- API Gatewayのログを確認
SELECT 
  timestamp,
  event_message,
  metadata
FROM edge_logs
WHERE 
  event_message LIKE '%401%'
ORDER BY timestamp DESC
LIMIT 50
```

---

## 🐛 考えられる原因

### 原因1: Authorizationヘッダーが正しく送信されていない

**確認方法**:
- Edge Functionの**Invocations**タブでリクエストヘッダーを確認
- `Authorization`ヘッダーが含まれているか確認

**解決方法**:
- `FunctionInvokeOptions`に`headers`を追加（既に実装済み）
- アクセストークンが正しく取得できているか確認

### 原因2: Supabase Swift SDKが自動的にAuthorizationヘッダーを追加していない

**確認方法**:
- Edge Functionの**Invocations**タブでリクエストヘッダーを確認
- `Authorization`ヘッダーが含まれていない場合、これが原因

**解決方法**:
- 手動でAuthorizationヘッダーを設定（既に実装済み）
- しかし、まだ401エラーが発生している場合は、別の問題の可能性

### 原因3: トークンの形式が間違っている

**確認方法**:
- Edge Functionの**Invocations**タブで`Authorization`ヘッダーの値を確認
- `Bearer <token>`の形式になっているか確認

**解決方法**:
- `Bearer `プレフィックスが正しく追加されているか確認

---

## ✅ 推奨される確認手順

### ステップ1: Edge FunctionのInvocationsタブを確認

1. Supabase Dashboard > **Edge Functions** > **save-transcript**
2. **Invocations**タブを開く
3. 最近の呼び出し（401エラー）をクリック
4. リクエストの詳細を確認：
   - **Headers**: `Authorization`ヘッダーが含まれているか
   - **Body**: リクエストボディが正しいか
   - **Error**: エラーメッセージの詳細

### ステップ2: リクエストヘッダーを確認

**Invocations**タブで確認すべき情報：

- `Authorization: Bearer eyJhbGciOiJFUzI1NiIs...` が含まれているか
- ヘッダーが正しく送信されているか

### ステップ3: エラーメッセージを確認

**Invocations**タブでエラーの詳細を確認：

- `"Unauthorized"` - 認証トークンが無効
- `"Invalid token"` - トークンの形式が間違っている
- `"Token expired"` - トークンが期限切れ

---

## 🔧 次のステップ

1. **Edge FunctionのInvocationsタブを確認**
   - リクエストヘッダーを確認
   - エラーメッセージの詳細を確認

2. **確認結果を共有**
   - `Authorization`ヘッダーが含まれているか
   - エラーメッセージの詳細

3. **必要に応じて修正**
   - エラーメッセージに基づいて適切な修正を行います

---

**最終更新**: 2026年1月27日
