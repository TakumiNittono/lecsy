import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

export type OrgRole = 'owner' | 'admin' | 'teacher' | 'student'

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
  }
}

/**
 * 現在のユーザーが指定組織で指定ロール以上かチェック
 * 失敗時はNextResponseを返す（APIルートでそのまま return できる）
 */
export async function requireOrgRole(
  slug: string,
  minimumRole: OrgRole
): Promise<OrgAuthResult | NextResponse> {
  const supabase = createClient()

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { data: org, error: orgError } = await supabase
    .from('organizations')
    .select('id, name, slug, type, plan, max_seats')
    .eq('slug', slug)
    .single()

  if (orgError || !org) {
    return NextResponse.json({ error: 'Organization not found' }, { status: 404 })
  }

  const { data: member, error: memberError } = await supabase
    .from('organization_members')
    .select('role')
    .eq('org_id', org.id)
    .eq('user_id', user.id)
    .single()

  if (memberError || !member) {
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
 * リダイレクトや条件分岐に使う
 */
export async function getOrgMembership(slug: string) {
  const supabase = createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  const { data: org } = await supabase
    .from('organizations')
    .select('id, name, slug, type, plan, max_seats')
    .eq('slug', slug)
    .single()

  if (!org) return null

  const { data: member } = await supabase
    .from('organization_members')
    .select('role')
    .eq('org_id', org.id)
    .eq('user_id', user.id)
    .single()

  if (!member) return null

  return {
    orgId: org.id,
    userId: user.id,
    userEmail: user.email || '',
    role: member.role as OrgRole,
    org,
  }
}

/**
 * ユーザーが所属する全組織を取得
 */
export async function getUserOrganizations() {
  const supabase = createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return []

  const { data: memberships } = await supabase
    .from('organization_members')
    .select('role, org_id, organizations(id, name, slug, type, plan)')
    .eq('user_id', user.id)

  if (!memberships) return []

  return memberships.map((m: any) => ({
    role: m.role as OrgRole,
    org: m.organizations,
  }))
}
