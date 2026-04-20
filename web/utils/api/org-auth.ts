import { cache } from 'react'
import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

export type OrgRole = 'owner' | 'admin' | 'teacher' | 'student'

/**
 * Single-request memoized auth lookup. Server-component render waves routinely
 * do auth.getUser() three+ times (layout → getOrgMembership → getUserOrganizations
 * → page → nested pickers), each a network round-trip to Supabase Auth. React
 * `cache()` de-dupes within one request so downstream callers share the first
 * lookup for free.
 */
const getCachedUser = cache(async () => {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  return user
})

const ROLE_HIERARCHY: Record<OrgRole, number> = {
  owner: 4,
  admin: 3,
  teacher: 2,
  student: 1,
}

export interface OrgAuthResult {
  orgId: string
  userId: string
  userEmail: string
  role: OrgRole
  org: {
    id: string
    name: string
    slug: string
    type: string
    plan: string
    max_seats: number
    logo_url: string | null
    settings: Record<string, any> | null
    trial_ends_at: string | null
  }
}

/**
 * 現在のユーザーが指定組織で指定ロール以上かチェック
 * データ取得はadmin client（RLSバイパス）、認証は通常クライアント
 */
export async function requireOrgRole(
  slug: string,
  minimumRole: OrgRole
): Promise<OrgAuthResult | NextResponse> {
  const user = await getCachedUser()
  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const admin = createAdminClient()

  const { data: org } = await admin
    .from('organizations')
    .select('id, name, slug, type, plan, max_seats, logo_url, settings, trial_ends_at')
    .eq('slug', slug)
    .single()

  if (!org) {
    return NextResponse.json({ error: 'Organization not found' }, { status: 404 })
  }

  const { data: member } = await admin
    .from('organization_members')
    .select('role')
    .eq('org_id', org.id)
    .eq('user_id', user.id)
    .eq('status', 'active')
    .single()

  if (!member) {
    return NextResponse.json({ error: 'Not a member of this organization' }, { status: 403 })
  }

  const userRole = member.role as OrgRole
  if (ROLE_HIERARCHY[userRole] < ROLE_HIERARCHY[minimumRole]) {
    return NextResponse.json({ error: 'Insufficient permissions' }, { status: 403 })
  }

  return {
    orgId: org.id,
    userId: user.id,
    userEmail: user.email || '',
    role: userRole,
    org,
  }
}

/**
 * サーバーコンポーネント用: ユーザーの組織メンバーシップを取得
 *
 * `cache()` 化済み: layout と子 page と nested server components が同じ slug で
 * 呼んでも Supabase への往復は1リクエスト内で1回だけになる。
 */
export const getOrgMembership = cache(async (slug: string) => {
  const user = await getCachedUser()
  if (!user) return null

  const admin = createAdminClient()

  // org + active membership を1往復で引く: join 無しでも2クエリだが、
  // cache() のおかげで同一リクエスト内では1回で済む。
  const { data: org } = await admin
    .from('organizations')
    .select('id, name, slug, type, plan, max_seats, logo_url, settings, trial_ends_at')
    .eq('slug', slug)
    .single()

  if (!org) return null

  const { data: member } = await admin
    .from('organization_members')
    .select('role')
    .eq('org_id', org.id)
    .eq('user_id', user.id)
    .eq('status', 'active')
    .single()

  if (!member) return null

  return {
    orgId: org.id,
    userId: user.id,
    userEmail: user.email || '',
    role: member.role as OrgRole,
    org,
  }
})

/**
 * ユーザーが所属する全組織を取得 (OrgSwitcher 用)
 */
export const getUserOrganizations = cache(async () => {
  const user = await getCachedUser()
  if (!user) return []

  const admin = createAdminClient()

  const { data: memberships } = await admin
    .from('organization_members')
    .select('role, org_id, organizations(id, name, slug, type, plan)')
    .eq('user_id', user.id)
    .eq('status', 'active')

  if (!memberships) return []

  return memberships.map((m: any) => ({
    role: m.role as OrgRole,
    org: m.organizations,
  }))
})
