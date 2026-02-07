// app/api/create-checkout-session/route.ts
// Stripe Checkout Session作成API

import { NextResponse } from "next/server";
import { createClient } from "@/utils/supabase/server";
import Stripe from "stripe";

// Stripeインスタンスの初期化（環境変数チェック付き）
let stripe: Stripe;
try {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error("STRIPE_SECRET_KEY is not set");
  }
  stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
    apiVersion: "2023-10-16",
  });
} catch (error: any) {
  console.error("Failed to initialize Stripe:", error.message);
  throw error;
}

// 動的レンダリングを強制（認証が必要なAPI）
export const dynamic = 'force-dynamic'

export async function POST(req: Request) {
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

    // Supabase認証チェック
    const supabase = createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
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
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3020";
    console.log("Creating checkout session with:", {
      customerId,
      priceId: process.env.STRIPE_PRICE_ID,
      appUrl,
      userId: user.id,
    });

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

    console.log("Checkout session created successfully:", session.id);

    return NextResponse.json({ url: session.url });
  } catch (error: any) {
    console.error("Error creating checkout session:", error);
    // 本番環境では詳細なエラー情報を返さない（セキュリティのため）
    const errorMessage = process.env.NODE_ENV === 'development' 
      ? error.message 
      : "Failed to create checkout session";
    
    return NextResponse.json(
      { error: "Internal server error", details: errorMessage },
      { status: 500 }
    );
  }
}
