# セキュリティ修正 #2: 所有権チェックの追加

**重要度**: 緊急  
**対象ファイル**: `supabase/functions/summarize/index.ts`  
**推定作業時間**: 15分

---

## 現状の問題

`summarize` Edge Functionで transcript の所有権チェックが不足しています。

```typescript
// 現在のコード (99-104行目)
const { data: transcript, error: transcriptError } = await supabase
  .from("transcripts")
  .select("id, content, title")
  .eq("id", body.transcript_id)
  .single();
```

**リスク**: 他のユーザーの `transcript_id` を指定して、そのユーザーの文字起こしの要約を取得できてしまいます。

---

## 修正手順

### Step 1: transcript 取得クエリに user_id を追加

**変更前** (99-104行目):
```typescript
// transcript取得
const { data: transcript, error: transcriptError } = await supabase
  .from("transcripts")
  .select("id, content, title")
  .eq("id", body.transcript_id)
  .single();
```

**変更後**:
```typescript
// transcript取得（所有権チェック付き）
const { data: transcript, error: transcriptError } = await supabase
  .from("transcripts")
  .select("id, content, title, user_id")
  .eq("id", body.transcript_id)
  .eq("user_id", user.id)  // 所有権チェックを追加
  .single();
```

---

### Step 2: キャッシュチェックにも user_id を追加

**変更前** (117-121行目):
```typescript
// キャッシュチェック
const { data: existingSummary } = await supabase
  .from("summaries")
  .select("*")
  .eq("transcript_id", body.transcript_id)
  .single();
```

**変更後**:
```typescript
// キャッシュチェック（所有権チェック付き）
const { data: existingSummary } = await supabase
  .from("summaries")
  .select("*")
  .eq("transcript_id", body.transcript_id)
  .eq("user_id", user.id)  // 所有権チェックを追加
  .single();
```

---

### Step 3: エラーメッセージの改善

**変更前** (106-113行目):
```typescript
if (transcriptError || !transcript) {
  return new Response(
    JSON.stringify({ error: "Transcript not found" }),
    { 
      status: 404,
      headers: { "Content-Type": "application/json" },
    }
  );
}
```

**変更後**:
```typescript
if (transcriptError || !transcript) {
  // 存在しない場合も権限がない場合も同じエラーを返す（情報漏洩防止）
  return new Response(
    JSON.stringify({ error: "Transcript not found or access denied" }),
    { 
      status: 404,
      headers: { "Content-Type": "application/json" },
    }
  );
}
```

---

## 完全な修正後のコード

```typescript
// supabase/functions/summarize/index.ts
// 99-134行目

// transcript取得（所有権チェック付き）
const { data: transcript, error: transcriptError } = await supabase
  .from("transcripts")
  .select("id, content, title, user_id")
  .eq("id", body.transcript_id)
  .eq("user_id", user.id)  // 所有権チェックを追加
  .single();

if (transcriptError || !transcript) {
  // 存在しない場合も権限がない場合も同じエラーを返す（情報漏洩防止）
  return new Response(
    JSON.stringify({ error: "Transcript not found or access denied" }),
    { 
      status: 404,
      headers: { "Content-Type": "application/json" },
    }
  );
}

// キャッシュチェック（所有権チェック付き）
const { data: existingSummary } = await supabase
  .from("summaries")
  .select("*")
  .eq("transcript_id", body.transcript_id)
  .eq("user_id", user.id)  // 所有権チェックを追加
  .single();

if (existingSummary) {
  if (body.mode === "summary" && existingSummary.summary) {
    return new Response(JSON.stringify(existingSummary), {
      headers: { "Content-Type": "application/json" },
    });
  }
  if (body.mode === "exam" && existingSummary.exam_mode) {
    return new Response(JSON.stringify(existingSummary), {
      headers: { "Content-Type": "application/json" },
    });
  }
}
```

---

## テスト方法

### テストケース 1: 自分の transcript で要約を生成

```bash
# 正常ケース - 自分のtranscriptで要約を生成
curl -X POST https://<project>.supabase.co/functions/v1/summarize \
  -H "Authorization: Bearer <your_access_token>" \
  -H "Content-Type: application/json" \
  -d '{"transcript_id":"<your_transcript_id>","mode":"summary"}'
```

期待される結果: 200 OK + 要約データ

### テストケース 2: 他人の transcript で要約を生成

```bash
# 異常ケース - 他人のtranscriptで要約を生成
curl -X POST https://<project>.supabase.co/functions/v1/summarize \
  -H "Authorization: Bearer <your_access_token>" \
  -H "Content-Type: application/json" \
  -d '{"transcript_id":"<other_users_transcript_id>","mode":"summary"}'
```

期待される結果: 404 Not Found
```json
{"error": "Transcript not found or access denied"}
```

---

## デプロイ手順

```bash
# Edge Functionを再デプロイ
cd supabase
supabase functions deploy summarize
```

---

## 確認チェックリスト

- [ ] transcript取得クエリに `eq("user_id", user.id)` を追加
- [ ] キャッシュチェックに `eq("user_id", user.id)` を追加
- [ ] エラーメッセージを統一（情報漏洩防止）
- [ ] 自分のtranscriptで要約生成が成功することを確認
- [ ] 他人のtranscript_idでは404エラーになることを確認
- [ ] 本番環境にデプロイ

---

## 関連ドキュメント

- [Supabase RLS Best Practices](https://supabase.com/docs/guides/auth/row-level-security)
- [OWASP - Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control/)
