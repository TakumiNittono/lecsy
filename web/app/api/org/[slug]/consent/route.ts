import { requireOrgRole } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

// Self-stamp FERPA consent on the caller's own membership row.
// Any active org member (including students) can call this endpoint for
// themselves. Idempotent — re-posting refreshes the timestamp, which is the
// desired behavior when a user re-accepts after a policy update.
export async function POST(
  _request: Request,
  { params }: { params: { slug: string } }
) {
  const result = await requireOrgRole(params.slug, 'student')
  if (result instanceof NextResponse) return result
  const { orgId, userId } = result

  const supabase = createAdminClient()
  const consentedAt = new Date().toISOString()

  const { error } = await supabase
    .from('organization_members')
    .update({ ferpa_consented_at: consentedAt })
    .eq('org_id', orgId)
    .eq('user_id', userId)

  if (error) {
    console.error('FERPA consent update failed:', error)
    return NextResponse.json({ error: 'Failed to record consent' }, { status: 500 })
  }

  return NextResponse.json({ ok: true, consented_at: consentedAt })
}

// Read the caller's consent status — used by the iOS client on launch to
// decide whether to surface the consent sheet.
export async function GET(
  _request: Request,
  { params }: { params: { slug: string } }
) {
  const result = await requireOrgRole(params.slug, 'student')
  if (result instanceof NextResponse) return result
  const { orgId, userId } = result

  const supabase = createAdminClient()
  const { data, error } = await supabase
    .from('organization_members')
    .select('ferpa_consented_at')
    .eq('org_id', orgId)
    .eq('user_id', userId)
    .single()

  if (error) {
    return NextResponse.json({ error: 'Failed to load consent status' }, { status: 500 })
  }

  return NextResponse.json({ consented_at: data?.ferpa_consented_at ?? null })
}
