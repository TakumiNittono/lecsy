# セキュリティ修正 #1: JWT検証の有効化

**重要度**: 緊急  
**対象ファイル**: `supabase/config.toml`  
**推定作業時間**: 5分

---

## 現状の問題

`save-transcript` Edge Functionで JWT 検証が無効化されています。

```toml
# supabase/config.toml (38-40行目)
# save-transcript関数のJWT検証を無効にする
[functions.save-transcript]
verify_jwt = false
```

**リスク**: JWT 検証がバイパスされ、認証なしでAPIにアクセスされる可能性があります。

---

## 修正手順

### Step 1: config.toml の修正

**変更前**:
```toml
# save-transcript関数のJWT検証を無効にする
[functions.save-transcript]
verify_jwt = false
```

**変更後**:
```toml
# save-transcript関数のJWT検証を有効にする（本番環境では必須）
[functions.save-transcript]
verify_jwt = true
```

---

### Step 2: Edge Function の確認

`supabase/functions/save-transcript/index.ts` では既にコード内で認証チェックが実装されていますが、`verify_jwt = true` を設定することで Supabase がリクエストレベルで JWT を検証します。

```typescript
// すでに実装済みの認証チェック（これは維持）
const authHeader = req.headers.get("Authorization");
if (!authHeader) {
  return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
}

const { data: { user }, error: authError } = await supabase.auth.getUser();
if (authError || !user) {
  return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
}
```

---

### Step 3: ローカルテスト

```bash
# Supabaseローカル環境を再起動
supabase stop
supabase start

# Edge Functionをローカルで起動
supabase functions serve save-transcript
```

テストリクエスト（認証なし - 401エラーを期待）:
```bash
curl -X POST http://localhost:54321/functions/v1/save-transcript \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Test content"}'
```

期待される結果:
```json
{"msg":"Invalid JWT"}
```

---

### Step 4: 本番環境へのデプロイ

```bash
# Edge Functionを再デプロイ
supabase functions deploy save-transcript

# 設定の反映を確認
supabase functions list
```

---

## 確認チェックリスト

- [ ] `config.toml` で `verify_jwt = true` に変更
- [ ] ローカル環境で認証なしリクエストが拒否されることを確認
- [ ] ローカル環境で認証ありリクエストが成功することを確認
- [ ] 本番環境にデプロイ
- [ ] iOSアプリから正常に文字起こし保存ができることを確認

---

## 補足: 本番環境の設定

Supabase ダッシュボードでも設定を確認できます：

1. Supabase ダッシュボードにログイン
2. 対象プロジェクトを選択
3. Edge Functions > save-transcript を選択
4. Settings タブで JWT 検証が有効になっていることを確認

---

## 関連ドキュメント

- [Supabase Edge Functions - Auth](https://supabase.com/docs/guides/functions/auth)
- [JWT Verification](https://supabase.com/docs/reference/cli/config-toml#functions)
