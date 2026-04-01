import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

const ADMIN_EMAIL = 'nittonotakumi@gmail.com'

export default async function AdminPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user || user.email !== ADMIN_EMAIL) {
    redirect('/app')
  }

  // 全組織を取得
  const { data: orgs } = await supabase
    .from('organizations')
    .select('*')
    .order('created_at', { ascending: false })

  // 全メンバー数を組織ごとにカウント
  const { data: memberCounts } = await supabase
    .from('organization_members')
    .select('org_id')

  const countByOrg: Record<string, number> = {}
  memberCounts?.forEach((m: any) => {
    countByOrg[m.org_id] = (countByOrg[m.org_id] || 0) + 1
  })

  // 全ユーザー数
  const { data: allTranscripts } = await supabase
    .from('transcripts')
    .select('id', { count: 'exact', head: true })

  // 全サブスクリプション
  const { data: subs } = await supabase
    .from('subscriptions')
    .select('status')

  const activeSubs = subs?.filter((s: any) => s.status === 'active').length || 0
  const totalSubs = subs?.length || 0

  const handleSignOut = async () => {
    'use server'
    const supabase = createClient()
    await supabase.auth.signOut()
    redirect('/login')
  }

  return (
    <main className="min-h-screen bg-gray-50">
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
              lecsy
            </Link>
            <span className="text-xs px-2 py-1 rounded-full bg-red-100 text-red-700 font-medium">
              Super Admin
            </span>
          </div>
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-sm text-gray-600 hover:text-gray-900">Dashboard</Link>
            <Link href="/app/reports" className="text-sm text-gray-600 hover:text-gray-900">Reports</Link>
            <span className="text-gray-700 text-sm">{user.email}</span>
            <form action={handleSignOut}>
              <button type="submit" className="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors font-medium">
                Logout
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Platform Admin</h1>
        <p className="text-gray-600 mb-8">Manage all organizations and users across Lecsy.</p>

        {/* Platform Stats */}
        <div className="grid md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-medium text-gray-500">Organizations</h2>
              <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
              </div>
            </div>
            <p className="text-3xl font-bold text-gray-900">{orgs?.length || 0}</p>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-medium text-gray-500">Total Members</h2>
              <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
            </div>
            <p className="text-3xl font-bold text-gray-900">{memberCounts?.length || 0}</p>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-medium text-gray-500">Active Subscriptions</h2>
              <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
            </div>
            <p className="text-3xl font-bold text-gray-900">{activeSubs} / {totalSubs}</p>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-medium text-gray-500">Total Transcripts</h2>
              <div className="w-10 h-10 bg-amber-100 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
            </div>
            <p className="text-3xl font-bold text-gray-900">{allTranscripts?.length ?? 0}</p>
          </div>
        </div>

        {/* Organizations List */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200">
          <div className="p-6 border-b border-gray-200 flex justify-between items-center">
            <h2 className="text-lg font-semibold text-gray-900">All Organizations</h2>
            <Link
              href="/org/new"
              className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
            >
              + New Organization
            </Link>
          </div>

          {orgs && orgs.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200 bg-gray-50">
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Name</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Plan</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Members</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Created</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {orgs.map((org: any) => (
                    <tr key={org.id} className="border-b border-gray-100 hover:bg-gray-50">
                      <td className="px-6 py-4">
                        <Link href={`/org/${org.slug}`} className="font-medium text-blue-600 hover:text-blue-800">
                          {org.name}
                        </Link>
                        <p className="text-xs text-gray-400">{org.slug}</p>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-600 capitalize">{org.type.replace('_', ' ')}</span>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                          org.plan === 'enterprise' ? 'bg-purple-100 text-purple-700' :
                          org.plan === 'growth' ? 'bg-blue-100 text-blue-700' :
                          'bg-gray-100 text-gray-700'
                        } capitalize`}>
                          {org.plan}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-900">{countByOrg[org.id] || 0} / {org.max_seats}</span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-500">
                          {new Date(org.created_at).toLocaleDateString()}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <Link
                          href={`/org/${org.slug}`}
                          className="text-sm text-blue-600 hover:text-blue-800 mr-4"
                        >
                          Manage
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="p-12 text-center">
              <p className="text-gray-500">No organizations yet.</p>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
