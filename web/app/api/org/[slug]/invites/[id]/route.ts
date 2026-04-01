import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

export async function DELETE(
  request: Request,
  { params }: { params: { slug: string; id: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const inviteId = params.id

  const supabase = createAdminClient()

  const { data: invite, error: fetchError } = await supabase
    .from('organization_invites')
    .select('id')
    .eq('id', inviteId)
    .eq('org_id', orgId)
    .single()

  if (fetchError || !invite) {
    return NextResponse.json({ error: 'Invite not found' }, { status: 404 })
  }

  const { error: deleteError } = await supabase
    .from('organization_invites')
    .delete()
    .eq('id', inviteId)
    .eq('org_id', orgId)

  if (deleteError) {
    console.error('Failed to delete invite:', deleteError)
    return NextResponse.json({ error: 'Failed to delete invite' }, { status: 500 })
  }

  return NextResponse.json({ success: true })
}

export async function PATCH(
  request: Request,
  { params }: { params: { slug: string; id: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId, userId } = result

  const supabase = createAdminClient()

  // Fetch the existing invite
  const { data: oldInvite, error: fetchError } = await supabase
    .from('organization_invites')
    .select('email, role')
    .eq('id', params.id)
    .eq('org_id', orgId)
    .single()

  if (fetchError || !oldInvite) {
    return NextResponse.json({ error: 'Invite not found' }, { status: 404 })
  }

  // Delete old invite
  await supabase
    .from('organization_invites')
    .delete()
    .eq('id', params.id)
    .eq('org_id', orgId)

  // Create new invite with same email and role
  const { data: newInvite, error: insertError } = await supabase
    .from('organization_invites')
    .insert({
      org_id: orgId,
      email: oldInvite.email,
      role: oldInvite.role,
      invited_by: userId,
    })
    .select()
    .single()

  if (insertError || !newInvite) {
    console.error('Failed to refresh invite:', insertError)
    return NextResponse.json({ error: 'Failed to refresh invite' }, { status: 500 })
  }

  return NextResponse.json({ invite: newInvite })
}
