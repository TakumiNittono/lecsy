'use client'

import { useState } from 'react'

interface Report {
  id: string
  user_id: string | null
  email: string | null
  category: string
  title: string
  description: string
  device_info: string | null
  app_version: string | null
  platform: string
  status: string
  admin_note: string | null
  created_at: string
}

const STATUS_COLORS: Record<string, string> = {
  open: 'bg-red-100 text-red-800',
  in_progress: 'bg-yellow-100 text-yellow-800',
  resolved: 'bg-green-100 text-green-800',
  closed: 'bg-gray-100 text-gray-800',
}

const STATUS_LABELS: Record<string, string> = {
  open: 'Open',
  in_progress: 'In Progress',
  resolved: 'Resolved',
  closed: 'Closed',
}

const CATEGORY_ICONS: Record<string, string> = {
  bug: '🐛',
  crash: '💥',
  feature: '💡',
  transcription: '💬',
  sync: '🔄',
  account: '👤',
  other: '📋',
}

const STATUSES = ['open', 'in_progress', 'resolved', 'closed']

export default function ReportList({ initialReports }: { initialReports: Report[] }) {
  const [reports, setReports] = useState<Report[]>(initialReports)
  const [filterStatus, setFilterStatus] = useState<string>('all')
  const [filterCategory, setFilterCategory] = useState<string>('all')
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [updatingId, setUpdatingId] = useState<string | null>(null)

  const filteredReports = reports.filter(r => {
    if (filterStatus !== 'all' && r.status !== filterStatus) return false
    if (filterCategory !== 'all' && r.category !== filterCategory) return false
    return true
  })

  const updateStatus = async (reportId: string, newStatus: string) => {
    setUpdatingId(reportId)
    try {
      const res = await fetch('/api/reports', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: reportId, status: newStatus }),
      })
      if (res.ok) {
        setReports(prev =>
          prev.map(r => r.id === reportId ? { ...r, status: newStatus } : r)
        )
      }
    } catch (err) {
      console.error('Failed to update status:', err)
    } finally {
      setUpdatingId(null)
    }
  }

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr)
    return d.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div>
      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-6">
        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value="all">All Statuses</option>
          {STATUSES.map(s => (
            <option key={s} value={s}>{STATUS_LABELS[s]}</option>
          ))}
        </select>

        <select
          value={filterCategory}
          onChange={(e) => setFilterCategory(e.target.value)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value="all">All Categories</option>
          {Object.entries(CATEGORY_ICONS).map(([key, icon]) => (
            <option key={key} value={key}>{icon} {key}</option>
          ))}
        </select>

        <div className="ml-auto text-sm text-gray-500 self-center">
          {filteredReports.length} report{filteredReports.length !== 1 ? 's' : ''}
        </div>
      </div>

      {/* Report Cards */}
      {filteredReports.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <p className="text-gray-500 text-lg">No reports found</p>
          <p className="text-gray-400 text-sm mt-1">Reports from users will appear here</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredReports.map((report) => (
            <div
              key={report.id}
              className="bg-white rounded-xl border border-gray-200 overflow-hidden transition-shadow hover:shadow-sm"
            >
              {/* Header row */}
              <button
                onClick={() => setExpandedId(expandedId === report.id ? null : report.id)}
                className="w-full px-5 py-4 flex items-center gap-3 text-left"
              >
                <span className="text-lg">{CATEGORY_ICONS[report.category] || '📋'}</span>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-medium text-gray-900 truncate">{report.title}</h3>
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[report.status]}`}>
                      {STATUS_LABELS[report.status]}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-gray-500">
                    <span>{formatDate(report.created_at)}</span>
                    <span>{report.platform}</span>
                    {report.email && <span>{report.email}</span>}
                    {report.app_version && <span>v{report.app_version}</span>}
                  </div>
                </div>
                <svg
                  className={`w-5 h-5 text-gray-400 transition-transform ${expandedId === report.id ? 'rotate-180' : ''}`}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {/* Expanded details */}
              {expandedId === report.id && (
                <div className="px-5 pb-5 border-t border-gray-100">
                  <div className="mt-4 space-y-4">
                    {/* Description */}
                    <div>
                      <h4 className="text-xs font-semibold text-gray-500 uppercase mb-1">Description</h4>
                      <p className="text-gray-800 text-sm whitespace-pre-wrap">{report.description}</p>
                    </div>

                    {/* Meta */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
                      {report.device_info && (
                        <div>
                          <span className="text-xs text-gray-500 block">Device</span>
                          <span className="text-gray-800">{report.device_info}</span>
                        </div>
                      )}
                      <div>
                        <span className="text-xs text-gray-500 block">Category</span>
                        <span className="text-gray-800 capitalize">{report.category}</span>
                      </div>
                      <div>
                        <span className="text-xs text-gray-500 block">User ID</span>
                        <span className="text-gray-800 font-mono text-xs">{report.user_id ? report.user_id.slice(0, 8) + '...' : 'Anonymous'}</span>
                      </div>
                      <div>
                        <span className="text-xs text-gray-500 block">Report ID</span>
                        <span className="text-gray-800 font-mono text-xs">{report.id.slice(0, 8)}...</span>
                      </div>
                    </div>

                    {/* Status Actions */}
                    <div className="flex items-center gap-2 pt-2">
                      <span className="text-xs text-gray-500 mr-1">Set status:</span>
                      {STATUSES.map(s => (
                        <button
                          key={s}
                          onClick={() => updateStatus(report.id, s)}
                          disabled={report.status === s || updatingId === report.id}
                          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                            report.status === s
                              ? 'bg-blue-600 text-white cursor-default'
                              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                          } ${updatingId === report.id ? 'opacity-50' : ''}`}
                        >
                          {STATUS_LABELS[s]}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
