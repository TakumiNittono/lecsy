# セキュリティ修正 #5: Stripe Webhook のエラーハンドリング強化

**重要度**: 緊急  
**対象ファイル**: `supabase/functions/stripe-webhook/index.ts`  
**推定作業時間**: 20分

---

## 現状の問題

### 問題 1: データベース操作のエラーチェックがない

```typescript
// 現在のコード (38-46行目)
await supabase.from("subscriptions").upsert({
  user_id: userId,
  status: "active",
  // ...
});
// エラーチェックがない
```

### 問題 2: メタデータの検証が不十分

```typescript
// 現在のコード (32行目)
const userId = session.metadata?.user_id;
// user_idの形式検証がない
```

### 問題 3: エラーメッセージがそのまま返される

```typescript
// 現在のコード (94行目)
return new Response(`Webhook Error: ${error.message}`, { status: 400 });
// 内部エラーの詳細が露出する可能性
```

---

## 修正手順

### Step 1: 完全な修正後のコード

```typescript
// supabase/functions/stripe-webhook/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
});

const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

// UUIDの形式を検証
function isValidUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
}

// エラーログを安全に記録
function logError(context: string, error: unknown): void {
  const errorMessage = error instanceof Error ? error.message : String(error);
  console.error(`[Stripe Webhook] ${context}:`, errorMessage);
}

serve(async (req) => {
  // 環境変数の確認
  if (!webhookSecret) {
    console.error("[Stripe Webhook] STRIPE_WEBHOOK_SECRET is not configured");
    return new Response("Server configuration error", { status: 500 });
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    console.warn("[Stripe Webhook] Missing stripe-signature header");
    return new Response("Missing signature", { status: 400 });
  }

  try {
    const body = await req.text();
    
    // Stripe署名の検証
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
    } catch (signatureError) {
      console.error("[Stripe Webhook] Signature verification failed");
      return new Response("Invalid signature", { status: 400 });
    }

    console.log(`[Stripe Webhook] Processing event: ${event.type}`);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.user_id;
        const subscriptionId = session.subscription as string;

        // メタデータの検証
        if (!userId) {
          console.error("[Stripe Webhook] Missing user_id in metadata");
          return new Response("Missing user_id", { status: 400 });
        }

        if (!isValidUUID(userId)) {
          console.error("[Stripe Webhook] Invalid user_id format:", userId);
          return new Response("Invalid user_id format", { status: 400 });
        }

        if (!subscriptionId) {
          console.error("[Stripe Webhook] Missing subscription ID");
          return new Response("Missing subscription ID", { status: 400 });
        }

        try {
          const subscription = await stripe.subscriptions.retrieve(subscriptionId);

          const { error: upsertError } = await supabase.from("subscriptions").upsert({
            user_id: userId,
            status: "active",
            provider: "stripe",
            stripe_customer_id: session.customer as string,
            stripe_subscription_id: subscriptionId,
            current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
            current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
          });

          if (upsertError) {
            logError("Failed to upsert subscription", upsertError);
            return new Response("Database error", { status: 500 });
          }

          console.log(`[Stripe Webhook] Subscription created for user: ${userId}`);
        } catch (stripeError) {
          logError("Failed to retrieve subscription from Stripe", stripeError);
          return new Response("Failed to retrieve subscription", { status: 500 });
        }
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;

        const { error: updateError } = await supabase
          .from("subscriptions")
          .update({
            status: subscription.status === "active" ? "active" : subscription.status,
            current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
            cancel_at_period_end: subscription.cancel_at_period_end,
          })
          .eq("stripe_subscription_id", subscription.id);

        if (updateError) {
          logError("Failed to update subscription", updateError);
          return new Response("Database error", { status: 500 });
        }

        console.log(`[Stripe Webhook] Subscription updated: ${subscription.id}`);
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;

        const { error: deleteError } = await supabase
          .from("subscriptions")
          .update({ status: "canceled" })
          .eq("stripe_subscription_id", subscription.id);

        if (deleteError) {
          logError("Failed to cancel subscription", deleteError);
          return new Response("Database error", { status: 500 });
        }

        console.log(`[Stripe Webhook] Subscription canceled: ${subscription.id}`);
        break;
      }

      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;
        const subscriptionId = invoice.subscription as string;

        if (subscriptionId) {
          const { error: paymentError } = await supabase
            .from("subscriptions")
            .update({ status: "past_due" })
            .eq("stripe_subscription_id", subscriptionId);

          if (paymentError) {
            logError("Failed to update payment status", paymentError);
            return new Response("Database error", { status: 500 });
          }

          console.log(`[Stripe Webhook] Payment failed for subscription: ${subscriptionId}`);
        }
        break;
      }

      default:
        console.log(`[Stripe Webhook] Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    logError("Unexpected error", error);
    // 内部エラーの詳細は返さない
    return new Response("Internal server error", { status: 500 });
  }
});
```

---

## 主な変更点

### 1. UUID形式の検証を追加
```typescript
function isValidUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
}

// 使用例
if (!isValidUUID(userId)) {
  console.error("[Stripe Webhook] Invalid user_id format:", userId);
  return new Response("Invalid user_id format", { status: 400 });
}
```

### 2. データベースエラーのチェックを追加
```typescript
const { error: upsertError } = await supabase.from("subscriptions").upsert({...});

if (upsertError) {
  logError("Failed to upsert subscription", upsertError);
  return new Response("Database error", { status: 500 });
}
```

### 3. エラーメッセージの安全化
```typescript
// 変更前
return new Response(`Webhook Error: ${error.message}`, { status: 400 });

// 変更後
return new Response("Internal server error", { status: 500 });
```

### 4. 署名検証の分離
```typescript
let event: Stripe.Event;
try {
  event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
} catch (signatureError) {
  console.error("[Stripe Webhook] Signature verification failed");
  return new Response("Invalid signature", { status: 400 });
}
```

---

## デプロイ手順

```bash
cd supabase
supabase functions deploy stripe-webhook
```

---

## テスト方法

### Stripe CLI でのテスト

```bash
# Stripe CLIをインストール
brew install stripe/stripe-cli/stripe

# ログイン
stripe login

# Webhookをローカルにフォワード
stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook

# 別ターミナルでテストイベントを送信
stripe trigger checkout.session.completed
```

### 不正なリクエストのテスト

```bash
# 署名なしリクエスト（400を期待）
curl -X POST http://localhost:54321/functions/v1/stripe-webhook \
  -H "Content-Type: application/json" \
  -d '{}'

# 不正な署名（400を期待）
curl -X POST http://localhost:54321/functions/v1/stripe-webhook \
  -H "Content-Type: application/json" \
  -H "stripe-signature: invalid" \
  -d '{}'
```

---

## 確認チェックリスト

- [ ] `isValidUUID` 関数を追加
- [ ] すべてのデータベース操作にエラーチェックを追加
- [ ] メタデータの検証を追加
- [ ] エラーメッセージを安全化
- [ ] 署名検証を分離
- [ ] ログ出力を追加
- [ ] Stripe CLIでテスト
- [ ] 本番環境にデプロイ

---

## 関連ドキュメント

- [Stripe Webhooks Best Practices](https://stripe.com/docs/webhooks/best-practices)
- [Stripe Signature Verification](https://stripe.com/docs/webhooks/signatures)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
