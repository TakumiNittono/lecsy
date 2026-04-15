// POST /api/stripe/portal
// Returns: { url } - Stripe Customer Portal URL
//
// 内部で Supabase Edge Function `create-portal-session` を呼び出す。

import { createClient } from '@/utils/supabase/server'
import { NextRequest, NextResponse } from 'next/server'
import { validateOrigin } from '@/utils/api/auth'

export const dynamic = 'force-dynamic'

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

    const { data: { session } } = await supabase.auth.getSession()
    if (!session) {
      return NextResponse.json({ error: 'No session' }, { status: 401 })
    }

    const origin = request.headers.get('origin') || process.env.NEXT_PUBLIC_APP_URL || 'https://www.lecsy.app'
    const return_url = `${origin}/app`

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const fnRes = await fetch(`${supabaseUrl}/functions/v1/create-portal-session`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ return_url }),
    })

    const fnJson = await fnRes.json().catch(() => ({}))
    if (!fnRes.ok) {
      return NextResponse.json(
        { error: fnJson.error || 'portal_failed' },
        { status: fnRes.status }
      )
    }

    return NextResponse.json({ url: fnJson.url })
  } catch (e) {
    console.error('[stripe/portal]', e)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
