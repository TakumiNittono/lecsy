import { authenticateRequest, validateOrigin } from '@/utils/api/auth'
import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

export async function POST(
  request: Request,
  { params }: { params: { token: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const { user, error: authError } = await authenticateRequest()
  if (authError) return authError

  const token = params.token

  if (!token || typeof token !== 'string' || token.length < 16) {
    return NextResponse.json({ error: 'Invalid token' }, { status: 400 })
  }

  const supabase = createClient()

  // Find invite by token
  const { data: invite, error: inviteError } = await supabase
    .from('organization_invites')
    .select('id, org_id, email, role, accepted, expires_at')
    .eq('token', token)
    .single()

  if (inviteError || !invite) {
    return NextResponse.json({ error: 'Invite not found' }, { status: 404 })
  }

  // Check if already accepted
  if (invite.accepted) {
    return NextResponse.json({ error: 'Invite has already been accepted' }, { status: 400 })
  }

  // Check if expired
  if (new Date(invite.expires_at) < new Date()) {
    return NextResponse.json({ error: 'Invite has expired' }, { status: 400 })
  }

  // Check if user is already a member
  const { data: existingMember } = await supabase
    .from('organization_members')
    .select('id')
    .eq('org_id', invite.org_id)
    .eq('user_id', user!.id)
    .single()

  if (existingMember) {
    return NextResponse.json(
      { error: 'You are already a member of this organization' },
      { status: 409 }
    )
  }

  // Add user to organization
  const { error: memberError } = await supabase
    .from('organization_members')
    .insert({
      org_id: invite.org_id,
      user_id: user!.id,
      role: invite.role,
    })

  if (memberError) {
    console.error('Failed to add member:', memberError)
    return NextResponse.json({ error: 'Failed to join organization' }, { status: 500 })
  }

  // Mark invite as accepted
  const { error: updateError } = await supabase
    .from('organization_invites')
    .update({ accepted: true })
    .eq('id', invite.id)

  if (updateError) {
    console.error('Failed to mark invite as accepted:', updateError)
    // Member was already added, so don't fail entirely
  }

  // Get org slug for redirect
  const { data: org } = await supabase
    .from('organizations')
    .select('slug')
    .eq('id', invite.org_id)
    .single()

  return NextResponse.json({
    success: true,
    slug: org?.slug,
  })
}
