# Edge Function Invocationsタブの確認方法

## 🔍 ログが見つからない場合の確認方法

`edge_logs`テーブルでログが見つからない場合、**Edge FunctionのInvocationsタブ**を直接確認してください。

---

## 📋 確認手順

### ステップ1: Edge Functionsページに移動

1. Supabase Dashboardの左サイドバーで「**Edge Functions**」をクリック
2. プロジェクトのEdge Functions一覧が表示されます

### ステップ2: save-transcript関数を選択

1. 「**save-transcript**」をクリック
2. 関数の詳細ページが開きます

### ステップ3: Invocationsタブを開く

1. 関数の詳細ページで「**Invocations**」タブをクリック
2. 最近の呼び出し履歴が表示されます

### ステップ4: 401エラーの呼び出しを確認

1. 401エラーが発生した呼び出しをクリック
2. 以下の情報を確認：
   - **Request Headers**: `Authorization`ヘッダーが含まれているか
   - **Request Body**: リクエストボディが正しいか
   - **Response**: エラーメッセージの詳細
   - **Status Code**: 401の詳細

---

## 🔍 確認すべきポイント

### 1. Authorizationヘッダー

**確認項目**:
- `Authorization: Bearer <token>`が含まれているか
- トークンが正しい形式か（`Bearer `プレフィックスが必要）

**期待される形式**:
```
Authorization: Bearer eyJhbGciOiJFUzI1NiIs...
```

### 2. エラーメッセージ

**確認項目**:
- エラーメッセージの詳細
- 401エラーの具体的な原因

**よくあるエラーメッセージ**:
- `"Unauthorized"` - 認証トークンが無効
- `"Invalid token"` - トークンの形式が間違っている
- `"Token expired"` - トークンが期限切れ
- `"Missing authorization header"` - Authorizationヘッダーが送信されていない

### 3. リクエストボディ

**確認項目**:
- `created_at`がISO 8601形式の文字列か
- すべての必須フィールドが含まれているか

**期待される形式**:
```json
{
  "title": "Jan 27, 2026 at 13:35",
  "content": "...",
  "created_at": "2026-01-27T13:35:00.000Z",
  "duration": 123.45,
  "language": "en",
  "app_version": "1.0.0"
}
```

---

## 🐛 よくある問題と解決方法

### 問題1: Authorizationヘッダーが送信されていない

**症状**:
- Invocationsタブで`Authorization`ヘッダーが見つからない
- エラーメッセージ: `"Missing authorization header"`

**解決方法**:
- `SyncService.swift`で`Authorization`ヘッダーを明示的に設定（既に実装済み）
- アクセストークンが正しく取得できているか確認

### 問題2: トークンの形式が間違っている

**症状**:
- `Authorization`ヘッダーが存在するが、形式が間違っている
- エラーメッセージ: `"Invalid token"`

**解決方法**:
- `Bearer `プレフィックスが正しく追加されているか確認
- トークンが正しくエンコードされているか確認

### 問題3: トークンが期限切れ

**症状**:
- `Authorization`ヘッダーが存在するが、トークンが期限切れ
- エラーメッセージ: `"Token expired"`

**解決方法**:
- セッションを再確認し、必要に応じて再ログイン

---

## 📸 確認結果の共有

Invocationsタブで確認した結果を共有してください：

1. **Authorizationヘッダー**: 含まれているか、形式は正しいか
2. **エラーメッセージ**: 具体的なエラーメッセージ
3. **リクエストボディ**: `created_at`の形式が正しいか

これらの情報に基づいて、適切な修正方法を提案します。

---

**最終更新**: 2026年1月27日
