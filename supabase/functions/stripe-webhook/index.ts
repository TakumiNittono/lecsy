// supabase/functions/stripe-webhook/index.ts
// Purpose: Stripeイベント処理

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

// ---- B2B price → plan name mapping (mirrors org-checkout) ----
function priceToPlan(priceId: string | null | undefined): string | null {
  if (!priceId) return null;
  const map: Record<string, string> = {
    [Deno.env.get("STRIPE_PRICE_STARTER_MONTHLY")  ?? "_"]: "starter",
    [Deno.env.get("STRIPE_PRICE_STARTER_YEARLY")   ?? "_"]: "starter",
    [Deno.env.get("STRIPE_PRICE_GROWTH_MONTHLY")   ?? "_"]: "growth",
    [Deno.env.get("STRIPE_PRICE_GROWTH_YEARLY")    ?? "_"]: "growth",
    [Deno.env.get("STRIPE_PRICE_BUSINESS_MONTHLY") ?? "_"]: "business",
    [Deno.env.get("STRIPE_PRICE_BUSINESS_YEARLY")  ?? "_"]: "business",
  };
  return map[priceId] ?? null;
}

async function writeOrgAudit(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  action: string,
  metadata: Record<string, unknown>,
) {
  try {
    await supabase.from("audit_logs").insert({
      org_id: orgId,
      actor_user_id: null,
      actor_email: "stripe-webhook",
      action,
      target_type: "subscription",
      target_id: (metadata.stripe_subscription_id as string) ?? null,
      metadata,
    });
  } catch (e) {
    console.error("[Stripe Webhook] audit insert failed", e);
  }
}

/**
 * Apply a Stripe subscription to the organizations row.
 * Returns true if the event was a B2B (org-scoped) event and was handled.
 */
async function applyB2BSubscription(
  supabase: ReturnType<typeof createClient>,
  subscription: Stripe.Subscription,
): Promise<boolean> {
  const orgId = subscription.metadata?.org_id;
  if (!orgId || !isValidUUID(orgId)) return false;

  const item = subscription.items?.data?.[0];
  const priceId = item?.price?.id;
  const quantity = item?.quantity ?? 0;
  const plan = priceToPlan(priceId);

  const update: Record<string, unknown> = {
    stripe_customer_id: subscription.customer as string,
    stripe_subscription_id: subscription.id,
    stripe_subscription_item_id: item?.id ?? null,
    seats_purchased: quantity,
    updated_at: new Date().toISOString(),
  };
  if (plan) update.plan = plan;

  const { error } = await supabase
    .from("organizations")
    .update(update)
    .eq("id", orgId);

  if (error) {
    logError(`Failed to update organization ${orgId}`, error);
    throw error;
  }

  await writeOrgAudit(supabase, orgId, "billing.subscription_synced", {
    stripe_subscription_id: subscription.id,
    plan,
    seats_purchased: quantity,
    status: subscription.status,
  });

  console.log(`[Stripe Webhook] B2B subscription synced for org ${orgId} (plan=${plan}, seats=${quantity})`);
  return true;
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
        const subscriptionId = session.subscription as string;

        // ---- B2B path: metadata.org_id present ----
        if (session.metadata?.org_id && subscriptionId) {
          try {
            const subscription = await stripe.subscriptions.retrieve(subscriptionId);
            await applyB2BSubscription(supabase, subscription);
          } catch (e) {
            logError("B2B checkout sync failed", e);
            return new Response("B2B sync failed", { status: 500 });
          }
          break;
        }

        const userId = session.metadata?.user_id;

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

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;

        // B2B path
        if (subscription.metadata?.org_id) {
          try {
            await applyB2BSubscription(supabase, subscription);
          } catch (e) {
            return new Response("B2B sync failed", { status: 500 });
          }
          break;
        }

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

        // B2B path: revert org to free / canceled
        if (subscription.metadata?.org_id && isValidUUID(subscription.metadata.org_id)) {
          const orgId = subscription.metadata.org_id;
          const { error: orgErr } = await supabase
            .from("organizations")
            .update({
              plan: "free",
              seats_purchased: 0,
              stripe_subscription_id: null,
              stripe_subscription_item_id: null,
              updated_at: new Date().toISOString(),
            })
            .eq("id", orgId);
          if (orgErr) {
            logError("Failed to cancel B2B subscription", orgErr);
            return new Response("Database error", { status: 500 });
          }
          await writeOrgAudit(supabase, orgId, "billing.subscription_canceled", {
            stripe_subscription_id: subscription.id,
          });
          console.log(`[Stripe Webhook] B2B subscription canceled for org ${orgId}`);
          break;
        }

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
