import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import UsageStats from '@/components/UsageStats'

export const dynamic = 'force-dynamic'

export default async function UsagePage({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)

  if (!membership || membership.role === 'student') {
    redirect('/app')
  }

  return (
    <div className="px-6 lg:px-10 py-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Usage Statistics</h1>
      <UsageStats slug={params.slug} role={membership.role} />
    </div>
  )
}
