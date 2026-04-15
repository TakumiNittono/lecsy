// POST /api/stripe/checkout
// Body: { plan: 'pro' | 'student', cycle?: 'monthly' | 'yearly' }
// Returns: { url } - Stripe Checkout URL to redirect to
//
// 内部で Supabase Edge Function `create-checkout-session` を呼び出す。
// Stripe シークレットはここでは扱わない。

import { createClient } from '@/utils/supabase/server'
import { NextRequest, NextResponse } from 'next/server'
import { validateOrigin } from '@/utils/api/auth'

export const dynamic = 'force-dynamic'

const VALID_PLANS = new Set(['pro', 'student'])
const VALID_CYCLES = new Set(['monthly', 'yearly'])

export async function POST(request: NextRequest) {
  try {
    if (!validateOrigin(request)) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json().catch(() => null)
    if (!body || typeof body !== 'object') {
      return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
    }

    const plan = body.plan
    const cycle = body.cycle ?? 'monthly'
    if (!VALID_PLANS.has(plan) || !VALID_CYCLES.has(cycle)) {
      return NextResponse.json({ error: 'Invalid plan or cycle' }, { status: 400 })
    }

    const origin = request.headers.get('origin') || process.env.NEXT_PUBLIC_APP_URL || 'https://www.lecsy.app'
    const success_url = `${origin}/app?stripe=success`
    const cancel_url = `${origin}/pricing?stripe=cancel`

    // Edge Function に user JWT を引き継いで委譲
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) {
      return NextResponse.json({ error: 'No session' }, { status: 401 })
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const fnRes = await fetch(`${supabaseUrl}/functions/v1/create-checkout-session`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ plan, cycle, success_url, cancel_url }),
    })

    const fnJson = await fnRes.json().catch(() => ({}))
    if (!fnRes.ok) {
      return NextResponse.json(
        { error: fnJson.error || 'checkout_failed' },
        { status: fnRes.status }
      )
    }

    return NextResponse.json({ url: fnJson.url })
  } catch (e) {
    console.error('[stripe/checkout]', e)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
