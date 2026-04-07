// Super admin management API.
// All routes gated to super admins only. Self-removal blocked.

import { NextResponse } from 'next/server'
import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { isSuperAdmin } from '@/utils/isSuperAdmin'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

async function gate() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user || !(await isSuperAdmin(user.email))) {
    return { user: null, response: NextResponse.json({ error: 'forbidden' }, { status: 403 }) }
  }
  return { user, response: null as null }
}

export async function GET() {
  const { user, response } = await gate()
  if (response) return response

  const admin = createAdminClient()
  const { data, error } = await admin
    .from('super_admin_emails')
    .select('email, note, created_at')
    .order('created_at', { ascending: true })

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
  return NextResponse.json({ super_admins: data ?? [] })
}

export async function POST(req: Request) {
  const { user, response } = await gate()
  if (response) return response

  const body = await req.json().catch(() => null) as { email?: string; note?: string } | null
  if (!body?.email || !EMAIL_RE.test(body.email)) {
    return NextResponse.json({ error: 'invalid_email' }, { status: 400 })
  }

  const email = body.email.trim().toLowerCase()
  const note = body.note?.trim() || null

  const admin = createAdminClient()
  const { error } = await admin
    .from('super_admin_emails')
    .insert({ email, note })

  if (error) {
    if (error.code === '23505') {
      return NextResponse.json({ error: 'already_super_admin' }, { status: 409 })
    }
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  await admin.from('audit_logs').insert({
    org_id: null,
    actor_user_id: user!.id,
    actor_email: user!.email,
    action: 'super_admin.added',
    target_type: 'super_admin_email',
    target_id: email,
    metadata: { note },
  })

  return NextResponse.json({ ok: true, email }, { status: 201 })
}

export async function DELETE(req: Request) {
  const { user, response } = await gate()
  if (response) return response

  const url = new URL(req.url)
  const email = url.searchParams.get('email')?.toLowerCase().trim()
  if (!email || !EMAIL_RE.test(email)) {
    return NextResponse.json({ error: 'invalid_email' }, { status: 400 })
  }

  // Self-removal safety: prevent the caller from locking themselves out.
  if (email === user!.email?.toLowerCase()) {
    return NextResponse.json({ error: 'cannot_remove_self' }, { status: 400 })
  }

  const admin = createAdminClient()

  // Last super admin protection: keep at least one
  const { count } = await admin
    .from('super_admin_emails')
    .select('email', { count: 'exact', head: true })
  if ((count ?? 0) <= 1) {
    return NextResponse.json({ error: 'cannot_remove_last' }, { status: 400 })
  }

  const { error } = await admin
    .from('super_admin_emails')
    .delete()
    .eq('email', email)

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  await admin.from('audit_logs').insert({
    org_id: null,
    actor_user_id: user!.id,
    actor_email: user!.email,
    action: 'super_admin.removed',
    target_type: 'super_admin_email',
    target_id: email,
    metadata: {},
  })

  return NextResponse.json({ ok: true })
}
