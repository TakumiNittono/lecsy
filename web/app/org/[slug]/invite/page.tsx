import { createAdminClient } from '@/utils/supabase/admin'
import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import InviteManager from '@/components/InviteManager'

export const dynamic = 'force-dynamic'

export default async function InvitePage({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)

  if (!membership || (membership.role !== 'owner' && membership.role !== 'admin')) {
    redirect(`/org/${params.slug}`)
  }

  const admin = createAdminClient()

  // Fetch all invites (including accepted for history)
  const { data: invites } = await admin
    .from('organization_invites')
    .select('id, email, role, token, expires_at, created_at')
    .eq('org_id', membership.orgId)
    .eq('accepted', false)
    .order('created_at', { ascending: false })

  const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://www.lecsy.app'

  return (
    <div className="px-6 lg:px-10 py-8">
      <InviteManager
        slug={params.slug}
        initialInvites={invites || []}
        appUrl={appUrl}
        orgName={membership.org.name}
      />
    </div>
  )
}
