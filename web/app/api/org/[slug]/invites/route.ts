import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

const VALID_ROLES = ['admin', 'teacher', 'student'] as const
const MAX_EMAILS_PER_REQUEST = 100
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

/**
 * GET /api/org/[slug]/invites
 * pending メンバー一覧を取得（admin+）
 */
export async function GET(
  request: Request,
  { params }: { params: { slug: string } }
) {
  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const supabase = createAdminClient()

  const { data: pendingMembers, error } = await supabase
    .from('organization_members')
    .select('id, email, role, joined_at')
    .eq('org_id', orgId)
    .eq('status', 'pending')
    .order('joined_at', { ascending: false })

  if (error) {
    console.error('Failed to fetch pending members:', error)
    return NextResponse.json({ error: 'Failed to fetch pending members' }, { status: 500 })
  }

  return NextResponse.json({ pending: pendingMembers })
}

/**
 * POST /api/org/[slug]/invites
 * メールアドレス一括でメンバーを直接追加（pending状態）
 */
export async function POST(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId, org } = result

  const body = await request.json()
  const { emails, role } = body

  // Validate role
  if (!role || !VALID_ROLES.includes(role)) {
    return NextResponse.json(
      { error: 'Invalid role. Must be one of: admin, teacher, student' },
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

  const supabase = createAdminClient()

  // Check for existing members (active or pending) with these emails
  const { data: existingMembers } = await supabase
    .from('organization_members')
    .select('id, email, user_id, status')
    .eq('org_id', orgId)

  // Build set of existing emails (from email column + auth.users lookup)
  const existingEmails = new Set<string>()
  for (const m of existingMembers || []) {
    if (m.email) existingEmails.add(m.email.toLowerCase())
    if (m.user_id) {
      const { data } = await supabase.auth.admin.getUserById(m.user_id)
      if (data?.user?.email) existingEmails.add(data.user.email.toLowerCase())
    }
  }

  const duplicateEmails = normalizedEmails.filter(e => existingEmails.has(e))
  const newEmails = normalizedEmails.filter(e => !existingEmails.has(e))

  if (newEmails.length === 0) {
    return NextResponse.json(
      { error: `All emails are already members: ${duplicateEmails.join(', ')}` },
      { status: 409 }
    )
  }

  // Check seat limit
  const totalMembers = (existingMembers || []).length
  const totalAfterAdd = totalMembers + newEmails.length

  if (totalAfterAdd > org.max_seats) {
    return NextResponse.json(
      {
        error: `Seat limit exceeded. Max: ${org.max_seats}, current: ${totalMembers}, requesting: ${newEmails.length}`,
      },
      { status: 400 }
    )
  }

  // Create pending member records
  const memberRecords = newEmails.map(email => ({
    org_id: orgId,
    email,
    role,
    status: 'pending',
    user_id: null,
  }))

  const { data: createdMembers, error: insertError } = await supabase
    .from('organization_members')
    .insert(memberRecords)
    .select('id, email, role, status, joined_at')

  if (insertError) {
    console.error('Failed to add members:', insertError)
    return NextResponse.json({ error: 'Failed to add members' }, { status: 500 })
  }

  // Send invitation emails via Supabase Auth (built-in, no external service).
  // Failure to send is not fatal — the pending row exists and the user can still
  // sign in via Apple/Google with the same email to auto-activate.
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'https://www.lecsy.app'
  const redirectTo = `${appUrl}/login?org=${encodeURIComponent(params.slug)}`
  const inviteMetadata = {
    org_id: orgId,
    org_name: org.name,
    org_slug: params.slug,
    invited_role: role,
  }

  const invited: string[] = []
  const inviteFailed: { email: string; reason: string }[] = []

  for (const m of createdMembers ?? []) {
    if (!m.email) continue
    try {
      const { error: inviteErr } = await supabase.auth.admin.inviteUserByEmail(m.email, {
        data: inviteMetadata,
        redirectTo,
      })
      if (inviteErr) {
        // User already exists in auth → fall back to magic link so they still get notified.
        const msg = (inviteErr.message ?? '').toLowerCase()
        if (msg.includes('already') || msg.includes('exists') || (inviteErr as { status?: number }).status === 422) {
          const { error: linkErr } = await supabase.auth.admin.generateLink({
            type: 'magiclink',
            email: m.email,
            options: { data: inviteMetadata, redirectTo },
          })
          if (linkErr) {
            inviteFailed.push({ email: m.email, reason: linkErr.message })
          } else {
            invited.push(m.email)
          }
        } else {
          inviteFailed.push({ email: m.email, reason: inviteErr.message })
        }
      } else {
        invited.push(m.email)
      }
    } catch (e) {
      inviteFailed.push({ email: m.email, reason: (e as Error).message })
    }
  }

  return NextResponse.json({
    added: createdMembers,
    skipped: duplicateEmails,
    invited,
    invite_failed: inviteFailed,
  }, { status: 201 })
}
