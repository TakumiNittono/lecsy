# ホワイトリスト設定ガイド

## 概要

特定のユーザー（開発者・テスター）だけがStripe課金なしでAI機能を使えるようにするホワイトリスト機能の設定方法です。

## 仕組み

- ホワイトリストに登録されたメールアドレスのユーザーは、Pro状態チェックをスキップ
- それ以外のユーザーは従来通り、Stripe課金（`subscription.status === "active"`）が必要
- フェアリミット（日次20回）は全ユーザーに適用される

## 設定手順

### 1. Supabase Edge Functions の環境変数を設定

Supabase ダッシュボード → **Edge Functions** → **Settings** → **Secrets** に以下を追加：

```env
WHITELIST_EMAILS=your-email@example.com,tester@example.com,another-tester@gmail.com
```

- カンマ区切りで複数のメールアドレスを登録可能
- スペースは自動的にトリミングされる

### 2. Edge Function を再デプロイ

```bash
cd /Users/takuminittono/Desktop/iPhone\ app/lecsy/supabase
supabase functions deploy summarize
```

### 3. 動作確認

ホワイトリストに登録したメールアドレスでログインして、AI要約機能を試してみてください。

Supabase Edge Function のログで以下のメッセージが表示されれば成功です：

```
[Whitelisted user] your-email@example.com - skipping Pro check
```

## ログの確認方法

Supabase ダッシュボード → **Edge Functions** → **summarize** → **Logs** でリアルタイムログを確認できます。

## セキュリティ上の注意

- ホワイトリストのメールアドレスは機密情報として扱ってください
- `.env` ファイルには記載せず、Supabase の Secrets で管理してください
- 定期的にホワイトリストを見直して、不要なユーザーを削除してください

## トラブルシューティング

### ホワイトリストユーザーが403エラーになる

**原因**: 環境変数が設定されていない、またはメールアドレスが一致していない

**対策**:
1. Supabase ダッシュボードで `WHITELIST_EMAILS` が正しく設定されているか確認
2. ログインしているメールアドレスとホワイトリストのメールアドレスが完全一致しているか確認（大文字小文字も区別）
3. Edge Function を再デプロイ

### 他のユーザーが使えなくなった

**原因**: ホワイトリスト機能自体は正常です。一般ユーザーは従来通りStripe課金が必要です。

**対策**: 課金していないユーザーには「Pro subscription required」エラーが返されるのが正常な動作です。

## 実装の詳細

`supabase/functions/summarize/index.ts` の49-67行目で実装されています：

```typescript
// ホワイトリストチェック（環境変数から取得）
const whitelistEmails = Deno.env.get("WHITELIST_EMAILS") || "";
const whitelistedUsers = whitelistEmails.split(",").map(email => email.trim());
const isWhitelisted = user.email && whitelistedUsers.includes(user.email);

// ホワイトリストユーザーでない場合はPro状態チェック
if (!isWhitelisted) {
  const { data: subscription } = await supabase
    .from("subscriptions")
    .select("status")
    .eq("user_id", user.id)
    .single();

  if (!subscription || subscription.status !== "active") {
    return createErrorResponse(req, "Pro subscription required", 403);
  }
} else {
  console.log(`[Whitelisted user] ${user.email} - skipping Pro check`);
}
```

---

**作成日**: 2026年2月6日
