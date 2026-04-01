import { createClient } from '@/utils/supabase/server'
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

  const supabase = createClient()
  const { orgId, userId, org, role } = membership

  // Fetch all members for this organization
  const { data: members } = await supabase
    .from('organization_members')
    .select('id, user_id, role, joined_at')
    .eq('org_id', orgId)
    .order('joined_at', { ascending: true })

  // Try to get user emails from profiles table
  const memberList = members || []
  const userIds = memberList.map((m) => m.user_id)

  const emailMap = new Map<string, string>()

  if (userIds.length > 0) {
    // Try profiles table
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, email')
      .in('id', userIds)

    if (profiles) {
      profiles.forEach((p: any) => {
        if (p.email) emailMap.set(p.id, p.email)
      })
    }
  }

  // Current user's email is known from the session
  emailMap.set(userId, membership.userEmail)

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
