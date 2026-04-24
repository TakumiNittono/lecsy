// create-portal-session: Stripe Customer Portal session 発行
// 既存サブスクの解約・カード変更などに使う。
// 参照: Deepgram/EXECUTION_PLAN.md W06
//
// 入力: { return_url: string }
// 出力: { url: string }

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@14?target=denonext';
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';
import { alert } from '../_shared/alert.ts';

interface Payload {
  return_url: string;
}

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
    if (!body.return_url) return createErrorResponse(req, 'missing_return_url', 400);

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );
    const { data: sub } = await admin
      .from('subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!sub?.stripe_customer_id) {
      return createErrorResponse(req, 'no_customer', 404);
    }

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
      apiVersion: '2024-06-20',
    });

    const session = await stripe.billingPortal.sessions.create({
      customer: sub.stripe_customer_id,
      return_url: body.return_url,
    });

    return createJsonResponse(req, { url: session.url }, 200);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[create-portal-session]', msg);
    await alert({
      source: 'create-portal-session',
      level: 'error',
      message: `create_portal_session_failed: ${msg}`,
      error: e,
    });
    return createErrorResponse(req, msg, 500);
  }
});
