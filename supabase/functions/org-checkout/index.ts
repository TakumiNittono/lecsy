// org-checkout: Stripe Checkout Session を作成（B2B プラン）
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14?target=denonext';
import { createPreflightResponse, createJsonResponse, createErrorResponse } from '../_shared/cors.ts';
import { requireOrgRole, writeAudit, HttpError } from '../_shared/auth.ts';

interface Payload {
  org_id: string;
  plan: 'starter' | 'growth' | 'business';
  seats: number;
  success_url: string;
  cancel_url: string;
  billing_cycle?: 'monthly' | 'yearly';
}

const PRICE_MAP: Record<string, { monthly?: string; yearly?: string }> = {
  starter:  { monthly: Deno.env.get('STRIPE_PRICE_STARTER_MONTHLY'),  yearly: Deno.env.get('STRIPE_PRICE_STARTER_YEARLY') },
  growth:   { monthly: Deno.env.get('STRIPE_PRICE_GROWTH_MONTHLY'),   yearly: Deno.env.get('STRIPE_PRICE_GROWTH_YEARLY') },
  business: { monthly: Deno.env.get('STRIPE_PRICE_BUSINESS_MONTHLY'), yearly: Deno.env.get('STRIPE_PRICE_BUSINESS_YEARLY') },
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const body: Payload = await req.json();
    if (!body.org_id || !body.plan || !body.seats) throw new HttpError(400, 'missing_fields');
    if (body.seats < 1 || body.seats > 100000) throw new HttpError(400, 'invalid_seats');

    const cycle = body.billing_cycle ?? 'monthly';
    const priceId = PRICE_MAP[body.plan]?.[cycle];
    if (!priceId) throw new HttpError(400, 'invalid_plan_or_cycle');

    const { user, admin } = await requireOrgRole(req, body.org_id, 'owner');

    const { data: org, error: orgErr } = await admin
      .from('organizations')
      .select('id, name, stripe_customer_id')
      .eq('id', body.org_id)
      .single();
    if (orgErr || !org) throw new HttpError(404, 'org_not_found');

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, { apiVersion: '2024-06-20' });

    let customerId = org.stripe_customer_id;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        name: org.name,
        metadata: { org_id: org.id },
      });
      customerId = customer.id;
      await admin.from('organizations').update({ stripe_customer_id: customerId }).eq('id', org.id);
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      line_items: [{ price: priceId, quantity: body.seats }],
      success_url: body.success_url,
      cancel_url: body.cancel_url,
      subscription_data: { metadata: { org_id: org.id, plan: body.plan } },
      metadata: { org_id: org.id, plan: body.plan, seats: String(body.seats) },
      allow_promotion_codes: true,
      billing_address_collection: 'required',
      tax_id_collection: { enabled: true },
    });

    await writeAudit(admin, org.id, user.id, user.email!, 'billing.checkout_started', 'subscription', session.id, {
      plan: body.plan,
      seats: body.seats,
      cycle,
    });

    return createJsonResponse(req, { url: session.url, session_id: session.id });
  } catch (e) {
    if (e instanceof HttpError) return createErrorResponse(req, e.message, e.status);
    return createErrorResponse(req, 'internal_error', 500);
  }
});
