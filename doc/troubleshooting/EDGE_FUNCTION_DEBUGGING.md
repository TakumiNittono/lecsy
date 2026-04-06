# Edge Function トラブルシューティング

## ログ確認方法

### 方法1: Invocations タブ（推奨）

Supabase Dashboard > **Edge Functions** > 関数を選択 > **Invocations** タブ

各呼び出しをクリックすると以下が確認できる:
- **Request Headers**: `Authorization` ヘッダーの有無
- **Request Body**: 送信データ
- **Response**: エラーメッセージ
- **Logs**: `console.log` 出力

### 方法2: Logs & Analytics で SQL クエリ

```sql
SELECT timestamp, event_message, metadata
FROM edge_logs
WHERE event_message LIKE '%save-transcript%'
   OR event_message LIKE '%functions/v1/save-transcript%'
ORDER BY timestamp DESC
LIMIT 20
```

---

## よくあるエラーと解決方法

### 401 Unauthorized

**原因**: 認証トークンが無効・欠落・期限切れ

**確認ポイント**:
- `Authorization: Bearer eyJhbGci...` ヘッダーが含まれているか
- トークンが期限切れでないか（Logs の `Token expired` を確認）
- Supabase Swift SDK がトークンを正しく送信しているか

**解決方法**:
1. アプリで再ログイン
2. `accessToken` が正しく取得できているか確認
3. `Bearer ` プレフィックスが付いているか確認

### 400 Bad Request

**原因**: リクエストボディのバリデーションエラー

**よくある原因**:
- `content` が空
- `created_at` が ISO 8601 形式でない

### 403 Forbidden

**原因**: 権限不足（Pro subscription が必要な機能へのアクセス等）

---

## JWT 関連のデバッグ

### Logs で確認すべき出力

```
JWT token (first 50 chars): eyJhbGciOiJFUzI1NiIs...
JWT token length: 1387
JWT payload: {...}
JWT exp (expiration): 1234567890
Token expired: true/false
```

### エラーメッセージの意味

| メッセージ | 意味 |
|-----------|------|
| `Invalid JWT` | JWTトークンが無効 |
| `Token expired` | トークンが期限切れ |
| `Unauthorized` | 認証に失敗 |
| `Content is required` | content が空 |
| `Invalid date format` | created_at の形式エラー |

---

## Edge Function のデプロイ

```bash
cd supabase

# 個別デプロイ
supabase functions deploy save-transcript
supabase functions deploy summarize
supabase functions deploy stripe-webhook

# デプロイ後の確認
# Supabase Dashboard > Edge Functions で Status: Active を確認
```

---

## API Gateway レベルの 401

Edge Function のログに記録されない 401 エラーは、API Gateway レベルで弾かれている可能性がある。

確認:
```sql
SELECT timestamp, event_message, metadata
FROM edge_logs
WHERE event_message LIKE '%401%'
ORDER BY timestamp DESC
LIMIT 50
```
