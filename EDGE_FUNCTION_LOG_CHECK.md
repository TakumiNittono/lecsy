# Edge Function ログ確認ガイド

## 📍 ログ確認の2つの方法

### 方法1: Edge Functions の Invocations タブ（最も簡単・推奨）

#### 手順

1. **Supabase Dashboardにアクセス**
   - URL: https://supabase.com/dashboard
   - プロジェクト: `bjqilokchrqfxzimfnpm` を選択

2. **Edge Functionsに移動**
   - 左サイドバーで「**Edge Functions**」をクリック

3. **save-transcript関数を選択**
   - 関数一覧から「**save-transcript**」をクリック

4. **Invocationsタブを開く**
   - 「**Invocations**」タブをクリック
   - 最近の呼び出し履歴が表示されます

5. **詳細を確認**
   - 各呼び出しをクリックすると、以下の情報が表示されます：
     - **Request Headers**: `Authorization`ヘッダーが含まれているか
     - **Request Body**: 送信されたデータ
     - **Response**: エラーメッセージ（401エラーの場合）
     - **Logs**: Edge Function内の`console.log`の出力（最も重要！）

#### 確認すべきポイント

- **Authorizationヘッダー**: `Bearer eyJhbGciOiJFUzI1NiIs...` の形式になっているか
- **エラーメッセージ**: `"Invalid JWT"` の詳細な原因
- **Logs**: 以下のログが表示されているか
  - `JWT token (first 50 chars):`
  - `JWT token length:`
  - `JWT payload:`
  - `JWT exp (expiration):`
  - `Token expired:`

---

### 方法2: Logs & Analytics で SQL クエリを実行

#### 手順

1. **Logs & Analyticsに移動**
   - 左サイドバーで「**Logs & Analytics**」をクリック

2. **Queryタブを選択**
   - 「**Query**」タブをクリック

3. **以下のクエリを実行**

```sql
-- save-transcript Edge Functionの最近のログを確認
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

4. **結果を確認**
   - `event_message`: HTTPメソッド、ステータスコード、URL
   - `metadata`: リクエストの詳細情報（JSON形式）

---

## 🔍 特に確認すべきログ

### Edge Function内のconsole.log出力

Invocationsタブの「**Logs**」セクションで、以下のログを確認してください：

```
Request headers: {...}
Authorization header: Bearer eyJhbGciOiJFUzI1NiIs...
Authorization header length: 1400
JWT token (first 50 chars): eyJhbGciOiJFUzI1NiIsImt...
JWT token length: 1387
Supabase URL: https://bjqilokchrqfxzimfnpm.supabase.co
Supabase Anon Key (first 20 chars): sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH...
Calling supabase.auth.getUser()...
getUser result - user: null error: {...}
Auth error: {...}
JWT payload: {...}
JWT exp (expiration): 1234567890
JWT exp (date): 2026-01-27T14:00:00.000Z
Current time: 2026-01-27T14:30:00.000Z
Token expired: true/false
```

### エラーメッセージの確認

- `"Invalid JWT"` - JWTトークンが無効
- `"Token expired"` - トークンが期限切れ
- `"Unauthorized"` - 認証に失敗

---

## 📸 スクリーンショットの場所

### Invocationsタブの見つけ方

1. **Edge Functions** > **save-transcript** > **Invocations**
2. 最近の呼び出しが一覧表示されます
3. 各呼び出しをクリックすると詳細が表示されます

### Logsセクション

- Invocationsタブの詳細画面の下部に「**Logs**」セクションがあります
- ここに`console.log`の出力が表示されます

---

## 🎯 次のステップ

1. **Invocationsタブでログを確認**
   - 特に「Logs」セクションの`console.log`出力を確認

2. **ログの内容を共有**
   - `JWT payload`の内容
   - `JWT exp (expiration)`の値
   - `Token expired`の状態
   - エラーメッセージの詳細

3. **問題の特定**
   - ログの内容に基づいて、JWT検証が失敗する原因を特定します

---

**最終更新**: 2026年1月27日
