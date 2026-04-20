import { createAdminClient } from '@/utils/supabase/admin'
import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import MembersList from '@/components/MembersList'

export const dynamic = 'force-dynamic'

export default async function MembersPage({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)

  if (!membership) {
    redirect('/app')
  }

  if (membership.role === 'student') {
    redirect(`/org/${params.slug}`)
  }

  const admin = createAdminClient()
  const { orgId, userId, org, role } = membership

  // Fetch all members (active + pending)
  const { data: members } = await admin
    .from('organization_members')
    .select('id, user_id, email, role, status, joined_at')
    .eq('org_id', orgId)
    .order('joined_at', { ascending: true })

  const memberList = members || []

  // active メンバー (user_id あり) のメールと最終アクティビティを並列取得。
  // 以前は getUserById をシリアルループで呼んでいたため、メンバー数 ×
  // Supabase Admin API 往復ぶん画面表示が遅れていた (N+1)。
  // Promise.all で一括、さらに transcripts クエリも同時に走らせる。
  const activeUserIds = memberList
    .map((m) => m.user_id)
    .filter((id): id is string => !!id)

  const [userEmailResults, transcriptsRes] = await Promise.all([
    Promise.all(
      activeUserIds.map(async (uid) => {
        const { data } = await admin.auth.admin.getUserById(uid)
        return [uid, data?.user?.email ?? null] as const
      })
    ),
    activeUserIds.length > 0
      ? admin
          .from('transcripts')
          .select('user_id, created_at')
          .in('user_id', activeUserIds)
          .order('created_at', { ascending: false })
      : Promise.resolve({ data: [] as Array<{ user_id: string; created_at: string }> }),
  ])

  const emailMap = new Map<string, string>()
  for (const [uid, email] of userEmailResults) {
    if (email) emailMap.set(uid, email)
  }

  const lastActiveMap = new Map<string, string>()
  for (const t of transcriptsRes.data || []) {
    if (!lastActiveMap.has(t.user_id)) {
      lastActiveMap.set(t.user_id, t.created_at)
    }
  }

  const membersWithEmail = memberList.map((m) => ({
    id: m.id,
    user_id: m.user_id,
    role: m.role,
    status: m.status || 'active',
    joined_at: m.joined_at,
    // pending メンバーは email カラムから、active は auth.users から
    email: m.user_id ? (emailMap.get(m.user_id) || m.email) : m.email,
    lastActive: m.user_id ? (lastActiveMap.get(m.user_id) || null) : null,
  }))

  return (
    <div className="px-6 lg:px-10 py-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Members</h1>
        <p className="text-sm text-gray-900 mt-1">
          Manage your organization members. Add members by email — they&apos;ll be activated automatically when they sign in.
        </p>
      </div>

      <MembersList
        members={membersWithEmail}
        currentUserId={userId}
        currentUserRole={role}
        slug={params.slug}
        maxSeats={org.max_seats}
      />
    </div>
  )
}
