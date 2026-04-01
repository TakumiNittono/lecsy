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

  // Fetch all members
  const { data: members } = await admin
    .from('organization_members')
    .select('id, user_id, role, joined_at')
    .eq('org_id', orgId)
    .order('joined_at', { ascending: true })

  const memberList = members || []

  // admin clientでメールアドレスを取得
  const emailMap = new Map<string, string>()
  for (const m of memberList) {
    const { data } = await admin.auth.admin.getUserById(m.user_id)
    if (data?.user?.email) {
      emailMap.set(m.user_id, data.user.email)
    }
  }

  const membersWithEmail = memberList.map((m) => ({
    id: m.id,
    user_id: m.user_id,
    role: m.role,
    joined_at: m.joined_at,
    email: emailMap.get(m.user_id) || null,
  }))

  return (
    <div className="px-6 lg:px-10 py-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Members</h1>
        <p className="text-sm text-gray-500 mt-1">
          Manage your organization members and their roles.
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
