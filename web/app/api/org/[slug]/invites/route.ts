import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

const VALID_INVITE_ROLES = ['teacher', 'student'] as const
const MAX_EMAILS_PER_REQUEST = 20
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export async function GET(
  request: Request,
  { params }: { params: { slug: string } }
) {
  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const supabase = createClient()

  const { data: invites, error } = await supabase
    .from('organization_invites')
    .select('id, email, role, accepted, expires_at, created_at, invited_by')
    .eq('org_id', orgId)
    .eq('accepted', false)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('Failed to fetch invites:', error)
    return NextResponse.json({ error: 'Failed to fetch invites' }, { status: 500 })
  }

  return NextResponse.json({ invites })
}

export async function POST(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId, userId, org } = result

  const body = await request.json()
  const { emails, role } = body

  // Validate role
  if (!role || !VALID_INVITE_ROLES.includes(role)) {
    return NextResponse.json(
      { error: 'Invalid role. Must be one of: teacher, student' },
      { status: 400 }
    )
  }

  // Validate emails
  if (!Array.isArray(emails) || emails.length === 0) {
    return NextResponse.json({ error: 'At least one email is required' }, { status: 400 })
  }

  if (emails.length > MAX_EMAILS_PER_REQUEST) {
    return NextResponse.json(
      { error: `Maximum ${MAX_EMAILS_PER_REQUEST} emails per request` },
      { status: 400 }
    )
  }

  const normalizedEmails = emails.map((e: string) => e.trim().toLowerCase())

  for (const email of normalizedEmails) {
    if (!EMAIL_REGEX.test(email)) {
      return NextResponse.json(
        { error: `Invalid email: ${email}` },
        { status: 400 }
      )
    }
  }

  const supabase = createClient()

  // Check for existing members with these emails
  const { data: existingMembers } = await supabase
    .from('organization_members')
    .select('user_id, users:user_id(email)')
    .eq('org_id', orgId)

  const memberEmails = new Set(
    (existingMembers || [])
      .map((m: any) => m.users?.email?.toLowerCase())
      .filter(Boolean)
  )

  const duplicateEmails = normalizedEmails.filter(e => memberEmails.has(e))
  if (duplicateEmails.length > 0) {
    return NextResponse.json(
      { error: `Already members: ${duplicateEmails.join(', ')}` },
      { status: 409 }
    )
  }

  // Check seat limit
  const { count: memberCount } = await supabase
    .from('organization_members')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)

  const { count: pendingInviteCount } = await supabase
    .from('organization_invites')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .eq('accepted', false)

  const totalAfterInvite =
    (memberCount || 0) + (pendingInviteCount || 0) + normalizedEmails.length

  if (totalAfterInvite > org.max_seats) {
    return NextResponse.json(
      {
        error: `Seat limit exceeded. Max: ${org.max_seats}, current members: ${memberCount || 0}, pending invites: ${pendingInviteCount || 0}, requesting: ${normalizedEmails.length}`,
      },
      { status: 400 }
    )
  }

  // Create invite records
  const inviteRecords = normalizedEmails.map(email => ({
    org_id: orgId,
    email,
    role,
    invited_by: userId,
  }))

  const { data: createdInvites, error: insertError } = await supabase
    .from('organization_invites')
    .insert(inviteRecords)
    .select('id, email, role, token, expires_at')

  if (insertError) {
    console.error('Failed to create invites:', insertError)
    return NextResponse.json({ error: 'Failed to create invites' }, { status: 500 })
  }

  // Build invite links
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://lecsy.app'
  const invites = (createdInvites || []).map(invite => ({
    id: invite.id,
    email: invite.email,
    role: invite.role,
    token: invite.token,
    expires_at: invite.expires_at,
    link: `${baseUrl}/invite/${invite.token}`,
  }))

  return NextResponse.json({ invites }, { status: 201 })
}
