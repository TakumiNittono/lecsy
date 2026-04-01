import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import OrgSettings from '@/components/OrgSettings'

export const dynamic = 'force-dynamic'

export default async function SettingsPage({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)

  if (!membership) {
    redirect('/app')
  }

  if (membership.role !== 'admin' && membership.role !== 'owner') {
    redirect(`/org/${params.slug}`)
  }

  return (
    <div className="px-6 lg:px-10 py-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Organization Settings</h1>
      <OrgSettings
        slug={params.slug}
        org={{
          name: membership.org.name,
          type: membership.org.type,
          plan: membership.org.plan,
        }}
        role={membership.role}
      />
    </div>
  )
}
