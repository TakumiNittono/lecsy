import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import ImportClient from './ImportClient'

export const dynamic = 'force-dynamic'

export default async function MembersImportPage({ params }: { params: { slug: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const admin = createAdminClient()
  const { data: org } = await admin
    .from('organizations')
    .select('id, name, slug, max_seats, allowed_email_domains')
    .eq('slug', params.slug)
    .single()
  if (!org) redirect('/app')

  // role check (admin+)
  const { data: ok } = await admin.rpc('is_org_role_at_least', {
    p_org: org.id,
    p_user: user.id,
    p_min: 'admin',
  })
  if (!ok) redirect(`/org/${params.slug}`)

  const { count: usedSeats } = await admin
    .from('organization_members')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', org.id)
    .in('status', ['active', 'pending'])

  return (
    <div className="max-w-4xl mx-auto p-6">
      <div className="mb-6">
        <Link href={`/org/${params.slug}/members`} className="text-sm text-gray-500 hover:text-gray-900">
          ← Back to members
        </Link>
      </div>
      <h1 className="text-2xl font-bold mb-2">Bulk import members</h1>
      <p className="text-gray-600 mb-6">
        Upload a CSV with columns: <code className="bg-gray-100 px-1">email</code>, <code className="bg-gray-100 px-1">role</code> (optional, defaults to <code>student</code>).
        Maximum 1000 rows per upload.
      </p>

      <div className="mb-4 p-4 bg-gray-50 rounded text-sm">
        <div><strong>Organization:</strong> {org.name}</div>
        <div><strong>Seats used:</strong> {usedSeats ?? 0} / {org.max_seats}</div>
        {org.allowed_email_domains?.length > 0 && (
          <div><strong>Allowed domains:</strong> {org.allowed_email_domains.join(', ')}</div>
        )}
      </div>

      <ImportClient orgId={org.id} slug={params.slug} />
    </div>
  )
}
