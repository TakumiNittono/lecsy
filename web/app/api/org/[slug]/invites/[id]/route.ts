import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createClient } from '@/utils/supabase/server'
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

  const supabase = createClient()

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
