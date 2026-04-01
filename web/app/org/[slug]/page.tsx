import { createAdminClient } from '@/utils/supabase/admin'
import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function OrgDashboardPage({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)

  if (!membership || membership.role === 'student') {
    redirect('/app')
  }

  const supabase = createAdminClient()
  const { orgId, org, role } = membership

  // ---------- Queries ----------

  // Total members
  const { count: totalMembers } = await supabase
    .from('organization_members')
    .select('*', { count: 'exact', head: true })
    .eq('org_id', orgId)

  // Get all member user_ids for aggregate queries
  const { data: members } = await supabase
    .from('organization_members')
    .select('user_id')
    .eq('org_id', orgId)

  const memberIds = members?.map((m) => m.user_id) || []

  // Current month boundaries
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 1).toISOString()
  // Previous month boundaries
  const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString()
  const prevMonthEnd = monthStart

  // Monthly recordings count
  let monthlyRecordings = 0
  let prevMonthlyRecordings = 0
  // Monthly total duration (seconds)
  let monthlyDuration = 0
  let prevMonthlyDuration = 0
  // Active users (last 7 days)
  let activeUsers = 0
  let prevActiveUsers = 0
  // New members this month
  let newMembersThisMonth = 0
  // Recent activity
  let recentActivity: Array<{
    id: string
    title: string | null
    created_at: string
    duration: number | null
    language: string | null
    user_email: string
  }> = []

  if (memberIds.length > 0) {
    // Monthly recordings
    const { count: recCount } = await supabase
      .from('transcripts')
      .select('*', { count: 'exact', head: true })
      .in('user_id', memberIds)
      .gte('created_at', monthStart)
      .lt('created_at', monthEnd)
    monthlyRecordings = recCount || 0

    // Monthly duration
    const { data: durationData } = await supabase
      .from('transcripts')
      .select('duration')
      .in('user_id', memberIds)
      .gte('created_at', monthStart)
      .lt('created_at', monthEnd)

    if (durationData) {
      monthlyDuration = durationData.reduce((sum, t) => {
        const d = t.duration != null ? (typeof t.duration === 'string' ? parseFloat(t.duration) : t.duration) : 0
        return sum + (isNaN(d) ? 0 : d)
      }, 0)
    }

    // Active users (last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
    const { data: activeData } = await supabase
      .from('transcripts')
      .select('user_id')
      .in('user_id', memberIds)
      .gte('created_at', sevenDaysAgo)

    if (activeData) {
      const uniqueUsers = new Set(activeData.map((t) => t.user_id))
      activeUsers = uniqueUsers.size
    }

    // --- Previous month data for trends ---
    const { count: prevRecCount } = await supabase
      .from('transcripts')
      .select('*', { count: 'exact', head: true })
      .in('user_id', memberIds)
      .gte('created_at', prevMonthStart)
      .lt('created_at', prevMonthEnd)
    prevMonthlyRecordings = prevRecCount || 0

    const { data: prevDurationData } = await supabase
      .from('transcripts')
      .select('duration')
      .in('user_id', memberIds)
      .gte('created_at', prevMonthStart)
      .lt('created_at', prevMonthEnd)

    if (prevDurationData) {
      prevMonthlyDuration = prevDurationData.reduce((sum, t) => {
        const d = t.duration != null ? (typeof t.duration === 'string' ? parseFloat(t.duration) : t.duration) : 0
        return sum + (isNaN(d) ? 0 : d)
      }, 0)
    }

    // Previous month active users (unique users who recorded)
    const { data: prevActiveData } = await supabase
      .from('transcripts')
      .select('user_id')
      .in('user_id', memberIds)
      .gte('created_at', prevMonthStart)
      .lt('created_at', prevMonthEnd)

    if (prevActiveData) {
      prevActiveUsers = new Set(prevActiveData.map((t) => t.user_id)).size
    }

    // Recent activity (last 10 transcripts with user emails)
    const { data: recentTranscripts } = await supabase
      .from('transcripts')
      .select('id, title, created_at, duration, language, user_id')
      .in('user_id', memberIds)
      .order('created_at', { ascending: false })
      .limit(10)

    if (recentTranscripts && recentTranscripts.length > 0) {
      // admin clientでauth.usersからメールを取得
      const userIds = [...new Set(recentTranscripts.map((t) => t.user_id))]
      const emailMap = new Map<string, string>()

      // service_roleならauth.admin.listUsersが使える
      for (const uid of userIds) {
        const { data } = await supabase.auth.admin.getUserById(uid)
        if (data?.user?.email) {
          emailMap.set(uid, data.user.email)
        }
      }

      recentActivity = recentTranscripts.map((t) => ({
        id: t.id,
        title: t.title,
        created_at: t.created_at,
        duration: t.duration != null ? (typeof t.duration === 'string' ? parseFloat(t.duration) : t.duration) : null,
        language: t.language,
        user_email: emailMap.get(t.user_id) || t.user_id.slice(0, 8) + '...',
      }))
    }
  }

  // Format monthly duration
  const durationHours = Math.floor(monthlyDuration / 3600)
  const durationMinutes = Math.floor((monthlyDuration % 3600) / 60)
  const monthlyDurationDisplay = durationHours > 0
    ? `${durationHours}h ${durationMinutes}m`
    : `${durationMinutes}m`

  // Trend helpers
  function calcTrend(current: number, previous: number): { delta: number; label: string } | null {
    if (previous === 0 && current === 0) return null
    if (previous === 0) return { delta: 100, label: '+100%' }
    const delta = ((current - previous) / previous) * 100
    return { delta, label: `${delta >= 0 ? '↑' : '↓'} ${Math.abs(delta).toFixed(0)}%` }
  }

  const recordingsTrend = calcTrend(monthlyRecordings, prevMonthlyRecordings)
  const durationTrend = calcTrend(monthlyDuration, prevMonthlyDuration)
  const activeUsersTrend = calcTrend(activeUsers, prevActiveUsers)

  // Plan badge color
  const planColors: Record<string, string> = {
    starter: 'bg-gray-100 text-gray-700',
    growth: 'bg-blue-100 text-blue-700',
    enterprise: 'bg-purple-100 text-purple-700',
  }
  const planBadgeClass = planColors[org.plan] || planColors.starter

  return (
    <div className="px-6 lg:px-10 py-8">
      {/* Org info bar */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-5 mb-8 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <h1 className="text-2xl font-bold text-gray-900">{org.name}</h1>
          <span className={`px-3 py-1 rounded-full text-xs font-semibold capitalize ${planBadgeClass}`}>
            {org.plan}
          </span>
        </div>
        <div className="text-sm text-gray-600">
          <span className="font-medium text-gray-900">{totalMembers ?? 0}</span> / {org.max_seats} seats used
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {/* Total Members */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Total Members</h2>
            <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
          </div>
          <p className="text-3xl font-bold text-gray-900">{totalMembers ?? 0}</p>
          <p className="text-sm text-gray-500 mt-2">Organization members</p>
        </div>

        {/* Monthly Recordings */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Monthly Recordings</h2>
            <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
              </svg>
            </div>
          </div>
          <p className="text-3xl font-bold text-gray-900">{monthlyRecordings}</p>
          <p className="text-sm text-gray-500 mt-1">Recordings this month</p>
          {recordingsTrend && (
            <p className={`text-xs mt-1 font-medium ${recordingsTrend.delta >= 0 ? 'text-green-600' : 'text-red-500'}`}>
              {recordingsTrend.label} vs last month
            </p>
          )}
        </div>

        {/* Monthly Duration */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Monthly Duration</h2>
            <div className="w-10 h-10 bg-amber-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <p className="text-3xl font-bold text-gray-900">{monthlyDurationDisplay}</p>
          <p className="text-sm text-gray-500 mt-1">Recorded this month</p>
          {durationTrend && (
            <p className={`text-xs mt-1 font-medium ${durationTrend.delta >= 0 ? 'text-green-600' : 'text-red-500'}`}>
              {durationTrend.label} vs last month
            </p>
          )}
        </div>

        {/* Active Users */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Active Users</h2>
            <div className="w-10 h-10 bg-emerald-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
          </div>
          <p className="text-3xl font-bold text-gray-900">{activeUsers}</p>
          <p className="text-sm text-gray-500 mt-1">Active in last 7 days</p>
          {activeUsersTrend && (
            <p className={`text-xs mt-1 font-medium ${activeUsersTrend.delta >= 0 ? 'text-green-600' : 'text-red-500'}`}>
              {activeUsersTrend.label} vs last month
            </p>
          )}
        </div>
      </div>

      {/* Quick Actions */}
      <div className="flex flex-wrap gap-3 mb-8">
        <Link
          href={`/org/${params.slug}/invite`}
          className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
          </svg>
          Invite Members
        </Link>
        <Link
          href={`/org/${params.slug}/usage`}
          className="inline-flex items-center gap-2 px-5 py-2.5 bg-white text-gray-700 text-sm font-medium rounded-lg border border-gray-300 hover:bg-gray-50 transition-colors"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
          </svg>
          View Usage
        </Link>
      </div>

      {/* Recent Activity */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Recent Activity</h2>
        </div>
        {recentActivity.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100">
                  <th className="text-left px-6 py-3 font-medium text-gray-500">User</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Title</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Date</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Duration</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Language</th>
                </tr>
              </thead>
              <tbody>
                {recentActivity.map((item) => {
                  const d = item.duration ?? 0
                  const mins = Math.floor(d / 60)
                  const secs = Math.floor(d % 60)
                  const durationStr = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`

                  return (
                    <tr key={item.id} className="border-b border-gray-50 hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-3 text-gray-700">{item.user_email}</td>
                      <td className="px-6 py-3 text-gray-900 font-medium">{item.title || 'Untitled'}</td>
                      <td className="px-6 py-3 text-gray-500">
                        {new Date(item.created_at).toLocaleDateString('en-US', {
                          month: 'short',
                          day: 'numeric',
                          year: 'numeric',
                        })}
                      </td>
                      <td className="px-6 py-3 text-gray-500">{item.duration != null ? durationStr : '-'}</td>
                      <td className="px-6 py-3">
                        {item.language ? (
                          <span className="px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 text-xs font-medium uppercase">
                            {item.language}
                          </span>
                        ) : (
                          <span className="text-gray-400">-</span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-center py-12">
            <svg className="w-12 h-12 text-gray-300 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
            </svg>
            <p className="text-gray-500">No recordings yet</p>
            <p className="text-sm text-gray-400 mt-1">Activity from organization members will appear here</p>
          </div>
        )}
      </div>
    </div>
  )
}
