// create-checkout-session: B2C個人ユーザー向け Stripe Checkout Session 発行
// 参照: Deepgram/EXECUTION_PLAN.md W06
//
// 入力: { plan: 'pro' | 'student', cycle: 'monthly' | 'yearly', success_url, cancel_url }
// 出力: { url: string }   (StripeのCheckout URL)
//
// 必要secret:
//   STRIPE_SECRET_KEY                       (test/live切替はキーで)
//   STRIPE_PRICE_PRO_MONTHLY                ($12.99/mo)
//   STRIPE_PRICE_PRO_YEARLY                 ($109/yr)
//   STRIPE_PRICE_STUDENT_MONTHLY            ($6.99/mo)
//   STRIPE_PRICE_STUDENT_YEARLY             ($59/yr)
//
// テストモードでは Stripe Dashboard で Test Price を作成し、上記envに格納する。

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@14?target=denonext';
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';

interface Payload {
  plan: 'pro' | 'student' | 'power';
  cycle?: 'monthly' | 'yearly';
  success_url: string;
  cancel_url: string;
}

const PRICE_MAP: Record<string, { monthly?: string; yearly?: string }> = {
  student: {
    monthly: Deno.env.get('STRIPE_PRICE_STUDENT_MONTHLY'),
    yearly: Deno.env.get('STRIPE_PRICE_STUDENT_YEARLY'),
  },
  pro: {
    monthly: Deno.env.get('STRIPE_PRICE_PRO_MONTHLY'),
    yearly: Deno.env.get('STRIPE_PRICE_PRO_YEARLY'),
  },
  power: {
    monthly: Deno.env.get('STRIPE_PRICE_POWER_MONTHLY'),
    yearly: Deno.env.get('STRIPE_PRICE_POWER_YEARLY'),
  },
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return createErrorResponse(req, 'unauthorized', 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return createErrorResponse(req, 'unauthorized', 401);

    const body: Payload = await req.json();
    const cycle = body.cycle ?? 'monthly';
    const priceId = PRICE_MAP[body.plan]?.[cycle];
    if (!priceId) return createErrorResponse(req, 'invalid_plan_or_cycle', 400);
    if (!body.success_url || !body.cancel_url) {
      return createErrorResponse(req, 'missing_redirect_urls', 400);
    }

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
      apiVersion: '2024-06-20',
    });

    // 既存 customer 検索 / 新規作成
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: sub } = await admin
      .from('subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .maybeSingle();

    let customerId = sub?.stripe_customer_id;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email ?? undefined,
        metadata: { user_id: user.id },
      });
      customerId = customer.id;
      await admin.from('subscriptions').upsert({
        user_id: user.id,
        status: 'free',
        provider: 'stripe',
        stripe_customer_id: customerId,
      });
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: body.success_url,
      cancel_url: body.cancel_url,
      allow_promotion_codes: true,
      metadata: {
        user_id: user.id,
        plan: body.plan,
        cycle,
      },
      subscription_data: {
        metadata: {
          user_id: user.id,
          plan: body.plan,
        },
      },
    });

    return createJsonResponse(req, { url: session.url }, 200);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[create-checkout-session]', msg);
    return createErrorResponse(req, msg, 500);
  }
});
