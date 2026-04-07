import { createAdminClient } from '@/utils/supabase/admin'
import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect, notFound } from 'next/navigation'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function StudentDetailPage({
  params,
}: {
  params: { slug: string; id: string }
}) {
  const membership = await getOrgMembership(params.slug)
  if (!membership || membership.role === 'student') {
    redirect('/app')
  }

  const admin = createAdminClient()
  const { orgId } = membership
  const studentId = params.id

  // Verify the target user is actually a member of THIS org. Otherwise an
  // admin could probe arbitrary auth.users.id by URL.
  const { data: member } = await admin
    .from('organization_members')
    .select('id, role, status, joined_at')
    .eq('org_id', orgId)
    .eq('user_id', studentId)
    .maybeSingle()

  if (!member) notFound()

  // Email from auth.users
  const { data: userResp } = await admin.auth.admin.getUserById(studentId)
  const email = userResp?.user?.email || studentId.slice(0, 8) + '…'

  // All transcripts this student created in THIS org
  const { data: transcripts } = await admin
    .from('transcripts')
    .select('id, title, created_at, duration, language, content')
    .eq('organization_id', orgId)
    .eq('user_id', studentId)
    .order('created_at', { ascending: false })

  const list = transcripts || []
  const total = list.length
  const totalDuration = list.reduce((sum, t) => {
    const d = t.duration != null ? (typeof t.duration === 'string' ? parseFloat(t.duration) : t.duration) : 0
    return sum + (isNaN(d) ? 0 : d)
  }, 0)

  // Language breakdown
  const langCounts = new Map<string, number>()
  for (const t of list) {
    const lang = t.language || 'unknown'
    langCounts.set(lang, (langCounts.get(lang) || 0) + 1)
  }
  const langBreakdown = [...langCounts.entries()].sort((a, b) => b[1] - a[1])

  // Last active
  const lastActive = list.length > 0 ? new Date(list[0].created_at) : null

  // Per-week activity (last 8 weeks) for a tiny bar chart
  const now = new Date()
  const weeks: { label: string; count: number }[] = []
  for (let w = 7; w >= 0; w--) {
    const weekStart = new Date(now)
    weekStart.setDate(now.getDate() - now.getDay() - w * 7)
    weekStart.setHours(0, 0, 0, 0)
    const weekEnd = new Date(weekStart)
    weekEnd.setDate(weekStart.getDate() + 7)
    const count = list.filter((t) => {
      const d = new Date(t.created_at)
      return d >= weekStart && d < weekEnd
    }).length
    weeks.push({
      label: weekStart.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      count,
    })
  }
  const maxWeek = Math.max(1, ...weeks.map((w) => w.count))

  const totalHours = Math.floor(totalDuration / 3600)
  const totalMinutes = Math.floor((totalDuration % 3600) / 60)
  const totalDurationDisplay = totalHours > 0 ? `${totalHours}h ${totalMinutes}m` : `${totalMinutes}m`

  return (
    <div className="px-6 lg:px-10 py-8">
      <div className="mb-6">
        <Link href={`/org/${params.slug}/transcripts`} className="text-sm text-blue-600 hover:underline">
          ← Back to all transcripts
        </Link>
        <h1 className="text-2xl font-bold text-gray-900 mt-2">{email}</h1>
        <p className="text-sm text-gray-500 mt-1">
          Member since {new Date(member.joined_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
          {' · '}
          Role: {member.role}
          {lastActive && <> · Last active: {lastActive.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</>}
        </p>
      </div>

      {/* Stat cards */}
      <div className="grid sm:grid-cols-3 gap-6 mb-8">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-sm font-medium text-gray-500">Total Recordings</h2>
          <p className="text-3xl font-bold text-gray-900 mt-2">{total}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-sm font-medium text-gray-500">Total Recorded Time</h2>
          <p className="text-3xl font-bold text-gray-900 mt-2">{totalDurationDisplay}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-sm font-medium text-gray-500">Languages</h2>
          <div className="flex flex-wrap gap-2 mt-3">
            {langBreakdown.length > 0 ? (
              langBreakdown.map(([lang, count]) => (
                <span key={lang} className="px-2 py-1 text-xs rounded-full bg-blue-50 text-blue-700 font-medium uppercase">
                  {lang} · {count}
                </span>
              ))
            ) : (
              <span className="text-sm text-gray-400">—</span>
            )}
          </div>
        </div>
      </div>

      {/* Activity chart */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Last 8 Weeks</h2>
        <div className="flex items-end gap-2 h-32">
          {weeks.map((w, i) => (
            <div key={i} className="flex-1 flex flex-col items-center justify-end gap-1">
              <div
                className="w-full bg-blue-500 rounded-t"
                style={{ height: `${(w.count / maxWeek) * 100}%`, minHeight: w.count > 0 ? '4px' : '0' }}
                title={`${w.count} recordings`}
              />
              <span className="text-[10px] text-gray-500">{w.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Transcript list */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">All Recordings</h2>
        </div>
        {list.length > 0 ? (
          <div className="divide-y divide-gray-100">
            {list.map((t) => {
              const d = t.duration != null ? (typeof t.duration === 'string' ? parseFloat(t.duration) : t.duration) : 0
              const mins = Math.floor(d / 60)
              const secs = Math.floor(d % 60)
              const durationStr = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`
              return (
                <div key={t.id} className="p-4">
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <h3 className="font-medium text-gray-900">{t.title || 'Untitled'}</h3>
                    <div className="flex items-center gap-3 text-xs text-gray-500">
                      <span>{new Date(t.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
                      <span>·</span>
                      <span>{durationStr}</span>
                      {t.language && (
                        <span className="px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 uppercase">{t.language}</span>
                      )}
                    </div>
                  </div>
                  {t.content && (
                    <p className="text-sm text-gray-600 mt-1 line-clamp-2">
                      {t.content.slice(0, 200)}
                      {t.content.length > 200 ? '…' : ''}
                    </p>
                  )}
                </div>
              )
            })}
          </div>
        ) : (
          <div className="text-center py-12">
            <p className="text-gray-500">No recordings yet</p>
          </div>
        )}
      </div>
    </div>
  )
}
