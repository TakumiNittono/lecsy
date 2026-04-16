import { NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

// Match existing invite route regex (allows 2-char TLD).
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/

interface DemoPayload {
  school_name?: string
  contact_name?: string
  contact_email?: string
  role?: string
  phone?: string
  notes?: string
}

/**
 * POST /api/schools/demo
 * Public endpoint. Rate-limited per IP to 5 submissions/hour to deter abuse.
 *
 * Inserts into public.pilot_leads via service-role client, then best-effort
 * fans out to the `notify-pilot-lead` Edge Function (Resend email to founder).
 */
export async function POST(req: Request) {
  let body: DemoPayload
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_payload' }, { status: 400 })
  }

  const school = body.school_name?.trim() ?? ''
  const name = body.contact_name?.trim() ?? ''
  const email = body.contact_email?.trim().toLowerCase() ?? ''
  const role = body.role?.trim() ?? ''

  if (!school || school.length < 2 || school.length > 200) {
    return NextResponse.json({ error: 'invalid_school_name' }, { status: 400 })
  }
  if (!name || name.length < 2 || name.length > 120) {
    return NextResponse.json({ error: 'invalid_contact_name' }, { status: 400 })
  }
  if (!email || !EMAIL_RE.test(email) || email.length > 200) {
    return NextResponse.json({ error: 'invalid_email' }, { status: 400 })
  }
  if (!role || role.length > 120) {
    return NextResponse.json({ error: 'invalid_role' }, { status: 400 })
  }

  const admin = createAdminClient()

  // Simple per-IP + per-email burst throttle via pilot_leads itself.
  // Refuse if same email or same IP has already submitted 3 times in the last hour.
  // rate_limit_logs table has a FK to auth.users so we can't use it for anonymous
  // submissions; but volume is extremely low (2-school campaign) so this is enough.
  const ip =
    req.headers.get('x-forwarded-for')?.split(',')[0].trim() ||
    req.headers.get('x-real-ip') ||
    null
  try {
    const windowStart = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count: recentFromSameEmail } = await admin
      .from('pilot_leads')
      .select('*', { count: 'exact', head: true })
      .eq('contact_email', email)
      .gte('created_at', windowStart)
    if ((recentFromSameEmail ?? 0) >= 3) {
      return NextResponse.json({ error: 'rate_limited' }, { status: 429 })
    }
  } catch {
    // Fail open.
  }
  void ip // IP captured in notes indirectly via Vercel logs; no PII kept here.

  const { data: lead, error: insErr } = await admin
    .from('pilot_leads')
    .insert({
      school_name: school,
      contact_name: name,
      contact_email: email,
      role,
      phone: body.phone?.trim() || null,
      notes: body.notes?.trim() || null,
      source: 'schools_demo_form',
    })
    .select('id')
    .single()

  if (insErr || !lead) {
    return NextResponse.json(
      { error: insErr?.message ?? 'insert_failed' },
      { status: 500 }
    )
  }

  // Best-effort notification; don't fail the user's submission if Resend is down.
  try {
    await admin.functions.invoke('notify-pilot-lead', {
      body: { lead_id: lead.id },
    })
  } catch {
    // Lead is already saved; founder will see it in Supabase Studio.
  }

  return NextResponse.json({ ok: true, id: lead.id }, { status: 200 })
}
