# Supabase セキュリティ設定確認ガイド

## 📍 確認場所と方法

### 1. JWT検証の確認

#### ✅ ローカル開発環境（config.toml）

**ファイル**: `supabase/config.toml`

```toml
# Edge Functions JWT設定
[functions.save-transcript]
verify_jwt = true  # ✅ 有効になっている

[functions.summarize]
verify_jwt = true  # ✅ 有効になっている
```

**確認方法**:
```bash
cat supabase/config.toml | grep verify_jwt
```

**期待される結果**:
```
verify_jwt = true
verify_jwt = true
```

---

#### ✅ 本番環境（Supabase Dashboard）

**確認手順**:

1. **Supabase Dashboardにログイン**
   - https://supabase.com/dashboard にアクセス
   - プロジェクトを選択

2. **Edge Functions設定を確認**
   - 左メニューから「Edge Functions」を選択
   - `save-transcript`関数をクリック
   - 「Settings」タブを開く
   - 「Verify JWT」が**ON**になっているか確認

3. **確認すべき設定**:
   ```
   ✅ Verify JWT: ON
   ✅ Invoke URL: https://[project-ref].supabase.co/functions/v1/save-transcript
   ```

**スクリーンショットで確認**:
- Edge Functions > save-transcript > Settings
- 「Verify JWT」のトグルがONになっていることを確認

---

### 2. 所有権チェック（user_id）の確認

#### ✅ コード内での確認

**ファイル**: `supabase/functions/summarize/index.ts`

**確認箇所**: 78-83行目

```typescript
// transcript取得（所有権チェック付き）
const { data: transcript, error: transcriptError } = await supabase
  .from("transcripts")
  .select("id, content, title, user_id")
  .eq("id", body.transcript_id)
  .eq("user_id", user.id)  // ✅ 所有権チェックが実装されている
  .single();
```

**確認方法**:
```bash
grep -n "user_id" supabase/functions/summarize/index.ts
```

**期待される結果**:
```
82:    .eq("user_id", user.id)  // 所有権チェック
95:    .eq("user_id", user.id)  // キャッシュチェックでも所有権チェック
```

---

#### ✅ データベースRLS（Row Level Security）の確認

**ファイル**: `supabase/migrations/001_initial_schema.sql`

**確認手順**:

1. **Supabase Dashboardにログイン**
   - https://supabase.com/dashboard にアクセス
   - プロジェクトを選択

2. **データベースRLSを確認**
   - 左メニューから「Database」>「Tables」を選択
   - `transcripts`テーブルをクリック
   - 「Policies」タブを開く

3. **確認すべきポリシー**:
   ```
   ✅ SELECT: 自分のデータのみ取得可能
   ✅ INSERT: 自分のデータのみ挿入可能
   ✅ UPDATE: 自分のデータのみ更新可能
   ✅ DELETE: 自分のデータのみ削除可能
   ```

**SQLで確認**:
```sql
-- Supabase DashboardのSQL Editorで実行
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'transcripts';
```

**期待される結果**:
- `user_id = auth.uid()` を含むポリシーが存在すること

---

### 3. Edge Functionコードでの確認

#### ✅ save-transcript関数

**ファイル**: `supabase/functions/save-transcript/index.ts`

**確認箇所**:
- 46-115行目: JWT検証とユーザー認証
- 132行目: `user_id: user.id` で自動的に所有権が設定される

```typescript
// ユーザー取得（JWT検証を含む）
const { data: { user }, error: authError } = await supabase.auth.getUser();

if (authError || !user) {
  return createErrorResponse(req, "Unauthorized", 401);
}

// 保存時にuser_idを自動設定（所有権チェック）
const { data, error } = await supabase
  .from("transcripts")
  .insert({
    user_id: user.id,  // ✅ 自動的に所有権が設定される
    // ...
  });
```

**評価**: ✅ JWT検証と所有権設定が実装されている

---

#### ✅ summarize関数

**ファイル**: `supabase/functions/summarize/index.ts`

**確認箇所**:
- 44-47行目: JWT検証
- 78-83行目: 所有権チェック（`.eq("user_id", user.id)`）
- 91-96行目: キャッシュチェックでも所有権チェック

```typescript
// JWT検証
const { data: { user } } = await supabase.auth.getUser();
if (!user) {
  return createErrorResponse(req, "Unauthorized", 401);
}

// 所有権チェック付きでtranscript取得
const { data: transcript } = await supabase
  .from("transcripts")
  .select("id, content, title, user_id")
  .eq("id", body.transcript_id)
  .eq("user_id", user.id)  // ✅ 所有権チェック
  .single();
```

**評価**: ✅ JWT検証と所有権チェックが実装されている

---

## 🔍 確認チェックリスト

### ローカル開発環境
- [x] `config.toml`で`verify_jwt = true`が設定されている
- [x] Edge FunctionコードでJWT検証が実装されている
- [x] Edge Functionコードで所有権チェックが実装されている

### 本番環境（Supabase Dashboard）
- [ ] Edge Functions > save-transcript > Settings > 「Verify JWT」がON
- [ ] Edge Functions > summarize > Settings > 「Verify JWT」がON
- [ ] Database > Tables > transcripts > Policies > RLSが有効
- [ ] Database > Tables > transcripts > Policies > `user_id = auth.uid()`のポリシーが存在

---

## 🧪 テスト方法

### 1. JWT検証のテスト

**正常なリクエスト**:
```bash
curl -X POST https://[project-ref].supabase.co/functions/v1/save-transcript \
  -H "Authorization: Bearer [valid-jwt-token]" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Test content","created_at":"2026-01-28T00:00:00Z"}'
```

**期待される結果**: `200 OK`（正常に保存される）

---

**無効なトークン**:
```bash
curl -X POST https://[project-ref].supabase.co/functions/v1/save-transcript \
  -H "Authorization: Bearer invalid-token" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Test content","created_at":"2026-01-28T00:00:00Z"}'
```

**期待される結果**: `401 Unauthorized`

---

**トークンなし**:
```bash
curl -X POST https://[project-ref].supabase.co/functions/v1/save-transcript \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Test content","created_at":"2026-01-28T00:00:00Z"}'
```

**期待される結果**: `401 Unauthorized`

---

### 2. 所有権チェックのテスト

**自分のtranscript_idで要約**:
```bash
curl -X POST https://[project-ref].supabase.co/functions/v1/summarize \
  -H "Authorization: Bearer [valid-jwt-token]" \
  -H "Content-Type: application/json" \
  -d '{"transcript_id":"[own-transcript-id]","mode":"summary"}'
```

**期待される結果**: `200 OK`（要約が生成される）

---

**他人のtranscript_idで要約**:
```bash
curl -X POST https://[project-ref].supabase.co/functions/v1/summarize \
  -H "Authorization: Bearer [valid-jwt-token]" \
  -H "Content-Type: application/json" \
  -d '{"transcript_id":"[other-user-transcript-id]","mode":"summary"}'
```

**期待される結果**: `404 Not Found`（所有権チェックにより拒否される）

---

## 📋 現在の状態

### ✅ 実装済み

1. **JWT検証**
   - ✅ `config.toml`で`verify_jwt = true`が設定されている
   - ✅ Edge Functionコードで`supabase.auth.getUser()`を使用してJWT検証
   - ✅ 認証エラー時に401を返す

2. **所有権チェック**
   - ✅ `save-transcript`: `user_id: user.id`で自動設定（RLSで保護）
   - ✅ `summarize`: `.eq("user_id", user.id)`で所有権チェック
   - ✅ キャッシュチェックでも所有権チェック

### ⚠️ 本番環境で確認が必要

1. **Supabase Dashboardでの設定確認**
   - Edge Functionsの「Verify JWT」設定
   - Database RLSポリシーの確認

2. **動作テスト**
   - 正常なリクエストが通るか
   - 無効なトークンが拒否されるか
   - 他人のデータにアクセスできないか

---

## 🎯 結論

**コードレベルでは、JWT検証と所有権チェックが適切に実装されています。**

**本番環境での確認手順**:
1. Supabase DashboardでEdge Functionsの設定を確認
2. Database RLSポリシーを確認
3. 上記のテストを実行して動作を確認

これらの確認が完了すれば、セキュリティ面で問題ありません。

---

**最終更新**: 2026年1月28日
