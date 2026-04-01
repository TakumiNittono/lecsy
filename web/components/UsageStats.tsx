'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'

interface UsageStatsProps {
  slug: string
  role: string
}

interface MemberUsage {
  user_id: string
  name: string
  email: string
  role: string
  recordings: number
  total_duration: number
  last_used: string | null
  languages: string[]
}

interface UsageData {
  summary: {
    total_recordings: number
    total_duration: number
    active_users: number
    total_users: number
    avg_duration_per_user: number
  }
  members: MemberUsage[]
}

type SortKey = 'name' | 'email' | 'role' | 'recordings' | 'total_duration' | 'last_used' | 'languages'
type SortDir = 'asc' | 'desc'

type Period = 'this_week' | 'this_month' | 'last_month'

function getPeriodDates(period: Period): { start: string; end: string } {
  const now = new Date()
  switch (period) {
    case 'this_week': {
      const day = now.getDay()
      const diff = now.getDate() - day + (day === 0 ? -6 : 1)
      const start = new Date(now.getFullYear(), now.getMonth(), diff)
      start.setHours(0, 0, 0, 0)
      const end = new Date(start)
      end.setDate(end.getDate() + 7)
      return { start: start.toISOString(), end: end.toISOString() }
    }
    case 'this_month': {
      const start = new Date(now.getFullYear(), now.getMonth(), 1)
      const end = new Date(now.getFullYear(), now.getMonth() + 1, 1)
      return { start: start.toISOString(), end: end.toISOString() }
    }
    case 'last_month': {
      const start = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const end = new Date(now.getFullYear(), now.getMonth(), 1)
      return { start: start.toISOString(), end: end.toISOString() }
    }
  }
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

const roleBadgeColors: Record<string, string> = {
  owner: 'bg-purple-100 text-purple-700',
  admin: 'bg-blue-100 text-blue-700',
  teacher: 'bg-green-100 text-green-700',
  student: 'bg-gray-100 text-gray-700',
}

export default function UsageStats({ slug, role }: UsageStatsProps) {
  const [period, setPeriod] = useState<Period>('this_month')
  const [data, setData] = useState<UsageData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [sortKey, setSortKey] = useState<SortKey>('recordings')
  const [sortDir, setSortDir] = useState<SortDir>('desc')

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { start, end } = getPeriodDates(period)
      const res = await fetch(`/api/org/${slug}/usage?start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}`)
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.error || 'Failed to fetch usage data')
      }
      const json = await res.json()
      setData(json)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [slug, period])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const sortedMembers = useMemo(() => {
    if (!data) return []
    const sorted = [...data.members]
    sorted.sort((a, b) => {
      let cmp = 0
      switch (sortKey) {
        case 'name':
          cmp = a.name.localeCompare(b.name)
          break
        case 'email':
          cmp = a.email.localeCompare(b.email)
          break
        case 'role':
          cmp = a.role.localeCompare(b.role)
          break
        case 'recordings':
          cmp = a.recordings - b.recordings
          break
        case 'total_duration':
          cmp = a.total_duration - b.total_duration
          break
        case 'last_used':
          cmp = (a.last_used || '').localeCompare(b.last_used || '')
          break
        case 'languages':
          cmp = a.languages.join(',').localeCompare(b.languages.join(','))
          break
      }
      return sortDir === 'asc' ? cmp : -cmp
    })
    return sorted
  }, [data, sortKey, sortDir])

  const handleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    } else {
      setSortKey(key)
      setSortDir('desc')
    }
  }

  const handleExportCSV = () => {
    if (!data) return
    const headers = ['Name', 'Email', 'Role', 'Recordings', 'Total Duration (s)', 'Last Used', 'Languages']
    const rows = sortedMembers.map((m) => [
      m.name,
      m.email,
      m.role,
      String(m.recordings),
      String(Math.round(m.total_duration)),
      m.last_used ? new Date(m.last_used).toLocaleDateString() : '',
      m.languages.join('; '),
    ])

    const csvContent = [headers, ...rows]
      .map((row) => row.map((cell) => `"${cell.replace(/"/g, '""')}"`).join(','))
      .join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `usage-${slug}-${period}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const SortIcon = ({ column }: { column: SortKey }) => {
    if (sortKey !== column) {
      return (
        <svg className="w-4 h-4 text-gray-300 ml-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
        </svg>
      )
    }
    return (
      <svg className="w-4 h-4 text-blue-600 ml-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={sortDir === 'asc' ? 'M5 15l7-7 7 7' : 'M19 9l-7 7-7-7'} />
      </svg>
    )
  }

  const periods: { key: Period; label: string }[] = [
    { key: 'this_week', label: 'This Week' },
    { key: 'this_month', label: 'This Month' },
    { key: 'last_month', label: 'Last Month' },
  ]

  return (
    <div>
      {/* Period selector */}
      <div className="flex flex-wrap items-center gap-2 mb-6">
        {periods.map((p) => (
          <button
            key={p.key}
            onClick={() => setPeriod(p.key)}
            className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
              period === p.key
                ? 'bg-blue-600 text-white'
                : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
            }`}
          >
            {p.label}
          </button>
        ))}
      </div>

      {loading && (
        <div className="text-center py-12">
          <div className="inline-block w-8 h-8 border-4 border-gray-200 border-t-blue-600 rounded-full animate-spin" />
          <p className="text-gray-500 mt-3">Loading usage data...</p>
        </div>
      )}

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4 mb-6">
          <p className="text-red-700 text-sm">{error}</p>
        </div>
      )}

      {data && !loading && (
        <>
          {/* Summary cards */}
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-sm font-medium text-gray-500">Total Recordings</h2>
                <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                  <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                  </svg>
                </div>
              </div>
              <p className="text-3xl font-bold text-gray-900">{data.summary.total_recordings}</p>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-sm font-medium text-gray-500">Total Duration</h2>
                <div className="w-10 h-10 bg-amber-100 rounded-lg flex items-center justify-center">
                  <svg className="w-6 h-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
              </div>
              <p className="text-3xl font-bold text-gray-900">{formatDuration(data.summary.total_duration)}</p>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-sm font-medium text-gray-500">Active Users</h2>
                <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                  <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
              </div>
              <p className="text-3xl font-bold text-gray-900">
                {data.summary.active_users} <span className="text-lg font-normal text-gray-400">/ {data.summary.total_users}</span>
              </p>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-sm font-medium text-gray-500">Avg Duration/User</h2>
                <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                  <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
              </div>
              <p className="text-3xl font-bold text-gray-900">{formatDuration(data.summary.avg_duration_per_user)}</p>
            </div>
          </div>

          {/* Actions row */}
          <div className="flex justify-end mb-4">
            <button
              onClick={handleExportCSV}
              className="inline-flex items-center gap-2 px-4 py-2 bg-white text-gray-700 text-sm font-medium rounded-lg border border-gray-300 hover:bg-gray-50 transition-colors"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              Export CSV
            </button>
          </div>

          {/* Members table */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-200 bg-gray-50">
                    {([
                      ['name', 'Name / Email'],
                      ['role', 'Role'],
                      ['recordings', 'Recordings'],
                      ['total_duration', 'Total Time'],
                      ['last_used', 'Last Used'],
                      ['languages', 'Languages'],
                    ] as [SortKey, string][]).map(([key, label]) => (
                      <th
                        key={key}
                        onClick={() => handleSort(key)}
                        className="text-left px-6 py-3 font-medium text-gray-500 cursor-pointer hover:text-gray-700 select-none"
                      >
                        {label}
                        <SortIcon column={key} />
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {sortedMembers.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-6 py-12 text-center text-gray-500">
                        No usage data for this period
                      </td>
                    </tr>
                  ) : (
                    sortedMembers.map((member) => (
                      <tr key={member.user_id} className="border-b border-gray-50 hover:bg-gray-50 transition-colors">
                        <td className="px-6 py-3">
                          <div className="font-medium text-gray-900">{member.name || 'Unknown'}</div>
                          <div className="text-gray-500 text-xs">{member.email}</div>
                        </td>
                        <td className="px-6 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${roleBadgeColors[member.role] || roleBadgeColors.student}`}>
                            {member.role}
                          </span>
                        </td>
                        <td className="px-6 py-3 text-gray-700">{member.recordings}</td>
                        <td className="px-6 py-3 text-gray-700">{formatDuration(member.total_duration)}</td>
                        <td className="px-6 py-3 text-gray-500">
                          {member.last_used
                            ? new Date(member.last_used).toLocaleDateString('en-US', {
                                month: 'short',
                                day: 'numeric',
                                year: 'numeric',
                              })
                            : '-'}
                        </td>
                        <td className="px-6 py-3">
                          <div className="flex flex-wrap gap-1">
                            {member.languages.length > 0
                              ? member.languages.map((lang) => (
                                  <span
                                    key={lang}
                                    className="px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 text-xs font-medium uppercase"
                                  >
                                    {lang}
                                  </span>
                                ))
                              : <span className="text-gray-400">-</span>}
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
