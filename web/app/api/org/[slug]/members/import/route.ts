import { NextResponse } from 'next/server'
import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'

export const dynamic = 'force-dynamic'

interface Row {
  email: string
  role?: 'student' | 'teacher' | 'admin'
  display_name?: string
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export async function POST(req: Request, { params }: { params: { slug: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 })

  const body = await req.json()
  const orgId: string = body.org_id
  const rows: Row[] = body.rows
  if (!orgId || !Array.isArray(rows)) {
    return NextResponse.json({ error: 'invalid_payload' }, { status: 400 })
  }
  if (rows.length === 0) return NextResponse.json({ error: 'empty_rows' }, { status: 400 })
  if (rows.length > 1000) return NextResponse.json({ error: 'too_many_rows' }, { status: 400 })

  const admin = createAdminClient()

  // role check
  const { data: roleOk } = await admin.rpc('is_org_role_at_least', {
    p_org: orgId,
    p_user: user.id,
    p_min: 'admin',
  })
  if (!roleOk) return NextResponse.json({ error: 'forbidden' }, { status: 403 })

  // org info
  const { data: org } = await admin
    .from('organizations')
    .select('id, name, max_seats, allowed_email_domains')
    .eq('id', orgId)
    .single()
  if (!org) return NextResponse.json({ error: 'org_not_found' }, { status: 404 })

  const { count: currentCount } = await admin
    .from('organization_members')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .in('status', ['active', 'pending'])

  const seatsAvailable = org.max_seats - (currentCount ?? 0)
  const allowedDomains: string[] = org.allowed_email_domains ?? []

  const successes: Array<{ email: string; status: string }> = []
  const failures: Array<{ row: number; email: string; reason: string }> = []
  let used = 0

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i]
    const email = r.email?.toLowerCase().trim()
    const role = r.role ?? 'student'

    if (!email || !EMAIL_RE.test(email)) {
      failures.push({ row: i + 1, email: r.email ?? '', reason: 'invalid_email' })
      continue
    }
    if (!['student', 'teacher', 'admin'].includes(role)) {
      failures.push({ row: i + 1, email, reason: 'invalid_role' })
      continue
    }
    if (allowedDomains.length > 0) {
      const dom = email.split('@')[1]
      if (!allowedDomains.includes(dom)) {
        failures.push({ row: i + 1, email, reason: 'domain_not_allowed' })
        continue
      }
    }
    if (used >= seatsAvailable) {
      failures.push({ row: i + 1, email, reason: 'seat_limit_exceeded' })
      continue
    }

    const { error } = await admin
      .from('organization_members')
      .insert({ org_id: orgId, email, role, status: 'pending' })

    if (error) {
      const code = (error as any).code
      if (code === '23505') failures.push({ row: i + 1, email, reason: 'duplicate' })
      else if (error.message?.includes('seat_limit_exceeded')) failures.push({ row: i + 1, email, reason: 'seat_limit_exceeded' })
      else failures.push({ row: i + 1, email, reason: error.message })
      continue
    }
    successes.push({ email, status: 'pending' })
    used++

    // Send invite email (best-effort, non-fatal). Built-in Supabase Auth invite.
    try {
      const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'https://www.lecsy.app'
      const redirectTo = `${appUrl}/login?org=${encodeURIComponent(params.slug)}`
      const meta = { org_id: orgId, org_name: org.name, org_slug: params.slug, invited_role: role }
      const { error: inviteErr } = await admin.auth.admin.inviteUserByEmail(email, { data: meta, redirectTo })
      if (inviteErr) {
        const msg = (inviteErr.message ?? '').toLowerCase()
        if (msg.includes('already') || msg.includes('exists') || (inviteErr as { status?: number }).status === 422) {
          await admin.auth.admin.generateLink({ type: 'magiclink', email, options: { data: meta, redirectTo } })
        }
      }
    } catch {
      // Swallow — pending row already created; user can still sign in via Apple/Google.
    }
  }

  // audit log
  await admin.rpc('write_audit_log', {
    p_org_id: orgId,
    p_action: 'org.csv_import',
    p_target_type: 'organization',
    p_target_id: orgId,
    p_metadata: { total: rows.length, ok: successes.length, ng: failures.length },
  })

  return NextResponse.json({
    successes,
    failures,
    summary: { total: rows.length, ok: successes.length, ng: failures.length },
  })
}
