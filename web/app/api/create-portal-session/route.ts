// app/api/create-portal-session/route.ts
// Stripe Customer Portal Session作成API

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/utils/supabase/server";
import Stripe from "stripe";
import { validateOrigin } from "@/utils/api/auth";
import { checkRateLimit, createRateLimitResponse } from "@/utils/rateLimit";

// 動的レンダリングを強制（認証が必要なAPI）
export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  try {
    // 環境変数チェック
    if (!process.env.STRIPE_SECRET_KEY) {
      console.error("Missing Stripe environment variables");
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
    const { allowed } = await checkRateLimit(supabase, user.id, 'portal', 10, 60 * 1000);
    if (!allowed) {
      return createRateLimitResponse() as NextResponse;
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
    const appUrl = process.env.NEXT_PUBLIC_APP_URL
      || (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "http://localhost:3020");
    const portalSession = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${appUrl}/app`,
    });

    return NextResponse.json({ url: portalSession.url });
  } catch (error: unknown) {
    console.error("Error creating portal session:", error instanceof Error ? error.message : "Unknown error");
    return NextResponse.json(
      { error: "Failed to create portal session" },
      { status: 500 }
    );
  }
}
