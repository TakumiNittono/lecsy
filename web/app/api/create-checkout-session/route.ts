// app/api/create-checkout-session/route.ts
// Stripe Checkout Session作成API

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/utils/supabase/server";
import Stripe from "stripe";
import { validateOrigin } from "@/utils/api/auth";
import { checkRateLimit, getClientIdentifier, createRateLimitResponse } from "@/utils/rateLimit";

// 動的レンダリングを強制（認証が必要なAPI）
export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  try {
    // 環境変数のチェック
    if (!process.env.STRIPE_SECRET_KEY) {
      console.error("STRIPE_SECRET_KEY is not set");
      return NextResponse.json(
        { error: "Server configuration error: STRIPE_SECRET_KEY is missing" },
        { status: 500 }
      );
    }

    if (!process.env.STRIPE_PRICE_ID) {
      console.error("STRIPE_PRICE_ID is not set");
      return NextResponse.json(
        { error: "Server configuration error: STRIPE_PRICE_ID is missing" },
        { status: 500 }
      );
    }

    // Stripeインスタンスの初期化（環境変数チェック後）
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
      apiVersion: "2023-10-16",
    });

    // CSRF対策: Origin/Referer検証
    if (!validateOrigin(req)) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    // Supabase認証チェック
    const supabase = createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // レート制限（1分間に5回まで）
    const identifier = getClientIdentifier(req, user.id);
    const { allowed, remaining, resetAt } = checkRateLimit(identifier, 5, 60 * 1000);
    if (!allowed) {
      return createRateLimitResponse(remaining, resetAt) as NextResponse;
    }

    // 既存のStripe Customerを確認
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .single();

    let customerId = subscription?.stripe_customer_id;

    // なければ作成
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { user_id: user.id },
      });
      customerId = customer.id;
    }

    // Checkout Session作成
    // Vercelデプロイ時はVERCEL_URLが自動設定される（プロトコルなし）
    const appUrl = process.env.NEXT_PUBLIC_APP_URL
      || (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "http://localhost:3020");

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [
        {
          price: process.env.STRIPE_PRICE_ID!,
          quantity: 1,
        },
      ],
      success_url: `${appUrl}/app?success=true`,
      cancel_url: `${appUrl}/app?canceled=true`,
      metadata: {
        user_id: user.id,
      },
    });

    return NextResponse.json({ url: session.url });
  } catch (error: unknown) {
    console.error("Error creating checkout session:", error);
    const errorMessage = process.env.NODE_ENV === 'development' && error instanceof Error
      ? error.message
      : "Failed to create checkout session";
    return NextResponse.json(
      { error: "Internal server error", details: errorMessage },
      { status: 500 }
    );
  }
}
