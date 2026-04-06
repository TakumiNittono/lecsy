# Supabase Edge Function ログ確認クエリ

## 🔍 現在の状況

`save-transcript` Edge Functionで401エラーが発生していますが、現在のログクエリでは該当するログが表示されていません。

---

## 📝 推奨ログクエリ

### 1. save-transcript Edge Functionのログを確認

Supabase Dashboard > **Logs & Analytics** > **Edge Functions**で以下のクエリを実行：

```sql
SELECT 
  timestamp,
  event_message,
  metadata
FROM edge_logs
WHERE 
  event_message LIKE '%save-transcript%'
  OR event_message LIKE '%functions/v1/save-transcript%'
ORDER BY timestamp DESC
LIMIT 20
```

### 2. 401エラーのログを確認

```sql
SELECT 
  timestamp,
  event_message,
  metadata
FROM edge_logs
WHERE 
  event_message LIKE '%401%'
  OR event_message LIKE '%Unauthorized%'
ORDER BY timestamp DESC
LIMIT 20
```

### 3. 最近のEdge Function呼び出しを確認

```sql
SELECT 
  timestamp,
  event_message,
  metadata
FROM edge_logs
WHERE 
  event_message LIKE '%functions/v1/%'
ORDER BY timestamp DESC
LIMIT 20
```

---

## 🔍 確認すべきポイント

### 1. エラーメッセージの確認

ログで以下の情報を確認：

- **エラーメッセージ**: `"Unauthorized"` または `"Invalid token"`
- **ステータスコード**: `401`
- **リクエストヘッダー**: `Authorization`ヘッダーが含まれているか
- **トークン**: トークンが正しく送信されているか

### 2. リクエストの詳細を確認

`metadata`カラムに以下の情報が含まれている可能性があります：

- `request.headers` - リクエストヘッダー
- `request.body` - リクエストボディ
- `error` - エラーの詳細

---

## 🐛 よくある原因と解決方法

### 原因1: Authorizationヘッダーが送信されていない

**確認方法**: ログで`Authorization`ヘッダーを確認

**解決方法**: 
- `FunctionInvokeOptions`に`headers`を追加（既に実装済み）
- アクセストークンが正しく取得できているか確認

### 原因2: トークンが無効または期限切れ

**確認方法**: ログでトークンの形式を確認

**解決方法**:
- セッションを再取得
- トークンの有効期限を確認

### 原因3: Edge Functionの認証設定

**確認方法**: Edge Functionのコードを確認

**解決方法**:
- `save-transcript/index.ts`で認証チェックが正しく実装されているか確認

---

## 📊 ログの見方

### 成功したリクエストの例

```
POST | 200 | ... | ... | https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/save-transcript
```

### 401エラーの例

```
POST | 401 | ... | ... | https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/save-transcript
```

### ログの構造

- **timestamp**: リクエストの時刻
- **event_message**: HTTPメソッド、ステータスコード、IPアドレス、URL
- **metadata**: リクエストの詳細情報（ヘッダー、ボディ、エラーなど）

---

## 🔄 次のステップ

1. **上記のクエリを実行**して、`save-transcript` Edge Functionのログを確認
2. **エラーメッセージを確認**して、具体的な原因を特定
3. **エラーメッセージを共有**していただければ、適切な修正方法を提案します

---

**最終更新**: 2026年1月27日
