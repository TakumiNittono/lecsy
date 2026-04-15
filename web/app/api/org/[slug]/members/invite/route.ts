import { NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { requireOrgRole } from '@/utils/api/org-auth'

export const dynamic = 'force-dynamic'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

/**
 * POST /api/org/[slug]/members/invite
 * Body: { email: string, role?: 'student'|'teacher'|'admin' }
 *
 * Inserts a pending organization_member row (idempotent on (org_id, email))
 * and fans out to the send-org-invite Edge Function so the user gets a
 * branded email (Resend) or Supabase magic link, depending on env config.
 */
export async function POST(
  req: Request,
  { params }: { params: { slug: string } }
) {
  // Resolve org via slug — never trust body.org_id (cross-org tampering).
  const auth = await requireOrgRole(params.slug, 'admin')
  if (auth instanceof NextResponse) return auth
  const { orgId } = auth

  let body: { email?: string; role?: 'student' | 'teacher' | 'admin' }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid_payload' }, { status: 400 })
  }

  const email = body.email?.toLowerCase().trim()
  const role = body.role ?? 'student'
  if (!email || !EMAIL_RE.test(email)) {
    return NextResponse.json({ error: 'invalid_email' }, { status: 400 })
  }
  if (!['student', 'teacher', 'admin'].includes(role)) {
    return NextResponse.json({ error: 'invalid_role' }, { status: 400 })
  }

  const admin = createAdminClient()

  // Domain restriction
  const { data: org } = await admin
    .from('organizations')
    .select('id, allowed_email_domains, max_seats')
    .eq('id', orgId)
    .single()
  if (!org) return NextResponse.json({ error: 'org_not_found' }, { status: 404 })

  const allowedDomains: string[] = org.allowed_email_domains ?? []
  if (allowedDomains.length > 0) {
    const dom = email.split('@')[1]
    if (!allowedDomains.includes(dom)) {
      return NextResponse.json({ error: 'domain_not_allowed' }, { status: 403 })
    }
  }

  // Seat check
  const { count: currentCount } = await admin
    .from('organization_members')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .in('status', ['active', 'pending'])
  if ((currentCount ?? 0) >= org.max_seats) {
    return NextResponse.json({ error: 'seat_limit_exceeded' }, { status: 409 })
  }

  // Insert pending membership (ignore duplicate so we can re-send invite)
  const { error: insErr } = await admin
    .from('organization_members')
    .insert({ org_id: orgId, email, role, status: 'pending' })

  if (insErr && (insErr as any).code !== '23505') {
    return NextResponse.json({ error: insErr.message }, { status: 500 })
  }

  // Fan out to Edge Function (best-effort but surface failures)
  const { error: fnErr } = await admin.functions.invoke('send-org-invite', {
    body: { org_id: orgId, email },
  })
  if (fnErr) {
    return NextResponse.json(
      { ok: true, warning: `invite_email_failed: ${fnErr.message}` },
      { status: 200 }
    )
  }

  return NextResponse.json({ ok: true, email, role })
}
