import { NextResponse } from 'next/server'
import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { isAdminOperator } from '@/utils/adminOperator'

export const dynamic = 'force-dynamic'

export async function POST(req: Request) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 })
  if (!isAdminOperator(user.email)) {
    return NextResponse.json({ error: 'forbidden' }, { status: 403 })
  }

  const { org_id, email } = await req.json()
  if (!org_id || !email) {
    return NextResponse.json({ error: 'missing_fields' }, { status: 400 })
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: 'invalid_email' }, { status: 400 })
  }

  const admin = createAdminClient()
  const normEmail = email.toLowerCase().trim()

  // Check existing
  const { data: existing } = await admin
    .from('organization_members')
    .select('id, role, status')
    .eq('org_id', org_id)
    .eq('email', normEmail)
    .maybeSingle()

  if (existing) {
    const { error } = await admin
      .from('organization_members')
      .update({ role: 'owner' })
      .eq('id', existing.id)
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })

    await admin.rpc('write_audit_log', {
      p_org_id: org_id,
      p_action: 'org.grant_ownership',
      p_target_type: 'member',
      p_target_id: existing.id,
      p_metadata: { email: normEmail, action: 'promoted' },
    })
    return NextResponse.json({ ok: true, action: 'promoted', member_id: existing.id })
  }

  const { data: created, error } = await admin
    .from('organization_members')
    .insert({ org_id, email: normEmail, role: 'owner', status: 'pending' })
    .select()
    .single()
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })

  await admin.rpc('write_audit_log', {
    p_org_id: org_id,
    p_action: 'org.grant_ownership',
    p_target_type: 'member',
    p_target_id: created.id,
    p_metadata: { email: normEmail, action: 'created' },
  })

  return NextResponse.json({ ok: true, action: 'created', member_id: created.id })
}
