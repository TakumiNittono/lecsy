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

  // active メンバー(user_id あり)のメールアドレスを取得
  const emailMap = new Map<string, string>()
  for (const m of memberList) {
    if (m.user_id) {
      const { data } = await admin.auth.admin.getUserById(m.user_id)
      if (data?.user?.email) {
        emailMap.set(m.user_id, data.user.email)
      }
    }
  }

  // 各メンバーの最終アクティビティを取得
  const activeUserIds = memberList.filter(m => m.user_id).map(m => m.user_id)
  const lastActiveMap = new Map<string, string>()
  if (activeUserIds.length > 0) {
    const { data: transcripts } = await admin
      .from('transcripts')
      .select('user_id, created_at')
      .in('user_id', activeUserIds)
      .order('created_at', { ascending: false })

    if (transcripts) {
      for (const t of transcripts) {
        if (!lastActiveMap.has(t.user_id)) {
          lastActiveMap.set(t.user_id, t.created_at)
        }
      }
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
        <p className="text-sm text-gray-700 mt-1">
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
