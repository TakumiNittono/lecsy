import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

const VALID_ROLES = ['admin', 'teacher', 'student'] as const

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

  const memberId = params.id

  const body = await request.json()
  const { role } = body

  if (!role || !VALID_ROLES.includes(role)) {
    return NextResponse.json(
      { error: 'Invalid role. Must be one of: admin, teacher, student' },
      { status: 400 }
    )
  }

  const supabase = createClient()

  // Fetch the target member
  const { data: targetMember, error: fetchError } = await supabase
    .from('organization_members')
    .select('id, user_id, role')
    .eq('id', memberId)
    .eq('org_id', orgId)
    .single()

  if (fetchError || !targetMember) {
    return NextResponse.json({ error: 'Member not found' }, { status: 404 })
  }

  // Cannot change owner role
  if (targetMember.role === 'owner') {
    return NextResponse.json({ error: 'Cannot change owner role' }, { status: 403 })
  }

  // Cannot change own role
  if (targetMember.user_id === userId) {
    return NextResponse.json({ error: 'Cannot change your own role' }, { status: 403 })
  }

  const { error: updateError } = await supabase
    .from('organization_members')
    .update({ role })
    .eq('id', memberId)
    .eq('org_id', orgId)

  if (updateError) {
    console.error('Failed to update member role:', updateError)
    return NextResponse.json({ error: 'Failed to update member role' }, { status: 500 })
  }

  return NextResponse.json({ success: true })
}

export async function DELETE(
  request: Request,
  { params }: { params: { slug: string; id: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId, userId } = result

  const memberId = params.id

  const supabase = createClient()

  // Fetch the target member
  const { data: targetMember, error: fetchError } = await supabase
    .from('organization_members')
    .select('id, user_id, role')
    .eq('id', memberId)
    .eq('org_id', orgId)
    .single()

  if (fetchError || !targetMember) {
    return NextResponse.json({ error: 'Member not found' }, { status: 404 })
  }

  // Cannot delete owner
  if (targetMember.role === 'owner') {
    return NextResponse.json({ error: 'Cannot remove the owner' }, { status: 403 })
  }

  // Cannot delete self
  if (targetMember.user_id === userId) {
    return NextResponse.json({ error: 'Cannot remove yourself' }, { status: 403 })
  }

  const { error: deleteError } = await supabase
    .from('organization_members')
    .delete()
    .eq('id', memberId)
    .eq('org_id', orgId)

  if (deleteError) {
    console.error('Failed to remove member:', deleteError)
    return NextResponse.json({ error: 'Failed to remove member' }, { status: 500 })
  }

  return NextResponse.json({ success: true })
}
