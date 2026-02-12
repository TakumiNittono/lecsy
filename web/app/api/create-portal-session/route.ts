// app/api/create-portal-session/route.ts
// Stripe Customer Portal Session作成API

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/utils/supabase/server";
import Stripe from "stripe";
import { validateOrigin } from "@/utils/api/auth";
import { checkRateLimit, getClientIdentifier, createRateLimitResponse } from "@/utils/rateLimit";

// 動的レンダリングを強制（認証が必要なAPI）
export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  try {
    // 環境変数チェック
    if (!process.env.STRIPE_SECRET_KEY) {
      console.error("STRIPE_SECRET_KEY is not set");
      return NextResponse.json(
        { error: "Server configuration error" },
        { status: 500 }
      );
    }

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

    // レート制限（1分間に10回まで）
    const identifier = getClientIdentifier(req, user.id);
    const { allowed, remaining, resetAt } = checkRateLimit(identifier, 10, 60 * 1000);
    if (!allowed) {
      return createRateLimitResponse(remaining, resetAt) as NextResponse;
    }

    // Stripe Customer IDを取得
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .single();

    if (!subscription?.stripe_customer_id) {
      return NextResponse.json(
        { error: "No subscription found" },
        { status: 404 }
      );
    }

    const customerId = subscription.stripe_customer_id;

    // Customer Portal Session作成
    const portalSession = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3020"}/app/settings`,
    });

    return NextResponse.json({ url: portalSession.url });
  } catch (error: unknown) {
    console.error("Error creating portal session:", error);
    const errorMessage = process.env.NODE_ENV === 'development' && error instanceof Error
      ? error.message
      : "Failed to create portal session";
    return NextResponse.json(
      { error: "Internal server error", details: errorMessage },
      { status: 500 }
    );
  }
}
