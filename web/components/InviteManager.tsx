'use client'

import { useState, useRef, useCallback } from 'react'
import BulkInviteUpload from './BulkInviteUpload'

interface Invite {
  id: string
  email: string
  role: string
  token: string
  expires_at: string
  created_at: string
}

interface Props {
  slug: string
  initialInvites: Invite[]
  appUrl: string
  orgName: string
}

export default function InviteManager({ slug, initialInvites, appUrl, orgName }: Props) {
  const [invites, setInvites] = useState<Invite[]>(initialInvites)
  const [role, setRole] = useState<'teacher' | 'student'>('student')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [copiedKey, setCopiedKey] = useState<string | null>(null)
  const [generatedLink, setGeneratedLink] = useState<string | null>(null)
  const [cancellingId, setCancellingId] = useState<string | null>(null)
  const [refreshingId, setRefreshingId] = useState<string | null>(null)
  const [showHistory, setShowHistory] = useState(false)
  const qrRef = useRef<HTMLDivElement>(null)

  const refreshInvites = useCallback(async () => {
    try {
      const res = await fetch(`/api/org/${slug}/invites`)
      const data = await res.json()
      if (res.ok && data.invites) {
        setInvites(data.invites)
      }
    } catch { /* ignore */ }
  }, [slug])

  const qrApiUrl = (text: string, size = 200) =>
    `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}&margin=8`

  async function copyToClipboard(text: string, key: string) {
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const ta = document.createElement('textarea')
      ta.value = text
      ta.style.cssText = 'position:fixed;opacity:0'
      document.body.appendChild(ta)
      ta.select()
      document.execCommand('copy')
      document.body.removeChild(ta)
    }
    setCopiedKey(key)
    setTimeout(() => setCopiedKey(null), 2000)
  }

  async function handleGenerateLink() {
    setLoading(true)
    setError(null)
    setGeneratedLink(null)

    try {
      const res = await fetch(`/api/org/${slug}/invites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ emails: [`invite-${role}@${slug}.lecsy`], role }),
      })

      const data = await res.json()

      if (!res.ok) {
        setError(data.error || 'Failed to generate link.')
        return
      }

      const newInvites: Invite[] = data.invites || []
      if (newInvites.length > 0) {
        const link = `${appUrl}/invite/${newInvites[0].token}`
        setGeneratedLink(link)
        setInvites((prev) => [...newInvites, ...prev])
      }
    } catch {
      setError('Network error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  async function handleCancelInvite(id: string) {
    if (!confirm('Cancel this invite?')) return
    setCancellingId(id)
    try {
      const res = await fetch(`/api/org/${slug}/invites/${id}`, { method: 'DELETE' })
      if (res.ok) {
        setInvites((prev) => prev.filter((inv) => inv.id !== id))
      }
    } catch { /* ignore */ } finally {
      setCancellingId(null)
    }
  }

  async function handleRefreshInvite(id: string) {
    setRefreshingId(id)
    try {
      const res = await fetch(`/api/org/${slug}/invites/${id}`, { method: 'PATCH' })
      const data = await res.json()
      if (res.ok && data.invite) {
        setInvites((prev) => [data.invite, ...prev.filter((inv) => inv.id !== id)])
      }
    } catch { /* ignore */ } finally {
      setRefreshingId(null)
    }
  }

  function isExpired(expiresAt: string) {
    return new Date(expiresAt) < new Date()
  }

  const activeInvites = invites.filter((inv) => !isExpired(inv.expires_at))
  const latestTeacher = activeInvites.find((inv) => inv.role === 'teacher')
  const latestStudent = activeInvites.find((inv) => inv.role === 'student')

  const teacherLink = latestTeacher ? `${appUrl}/invite/${latestTeacher.token}` : null
  const studentLink = latestStudent ? `${appUrl}/invite/${latestStudent.token}` : null

  return (
    <>
      <h1 className="text-2xl font-bold text-gray-900 mb-2">Invite Members</h1>
      <p className="text-gray-500 text-sm mb-8">Share a link or show the QR code in class.</p>

      {/* Quick Invite Cards */}
      <div className="grid md:grid-cols-2 gap-6 mb-8">
        {/* Student Invite */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="bg-green-50 border-b border-green-100 px-6 py-4 flex items-center gap-3">
            <div className="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
              <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div>
              <h2 className="font-semibold text-gray-900">Student Invite</h2>
              <p className="text-xs text-gray-500">Students can record and review lectures</p>
            </div>
          </div>
          <div className="p-6">
            {studentLink ? (
              <div className="space-y-4">
                {/* QR Code */}
                <div className="flex justify-center">
                  <div className="bg-white p-3 rounded-xl border-2 border-gray-100">
                    <img
                      src={qrApiUrl(studentLink, 180)}
                      alt="Student invite QR code"
                      width={180}
                      height={180}
                      className="rounded"
                    />
                  </div>
                </div>
                {/* Link + Copy */}
                <div className="flex items-center gap-2 bg-gray-50 rounded-lg px-3 py-2">
                  <input
                    type="text"
                    readOnly
                    value={studentLink}
                    className="flex-1 text-xs text-gray-500 bg-transparent border-none outline-none truncate"
                  />
                  <button
                    onClick={() => copyToClipboard(studentLink, 'student')}
                    className={`flex-shrink-0 px-3 py-1.5 rounded-md text-xs font-medium transition-all ${
                      copiedKey === 'student'
                        ? 'bg-green-500 text-white'
                        : 'bg-green-600 text-white hover:bg-green-700'
                    }`}
                  >
                    {copiedKey === 'student' ? 'Copied!' : 'Copy Link'}
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => { setRole('student'); handleGenerateLink() }}
                disabled={loading}
                className="w-full py-3 bg-green-600 text-white font-medium rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors"
              >
                {loading && role === 'student' ? 'Generating...' : 'Generate Student Link'}
              </button>
            )}
          </div>
        </div>

        {/* Teacher Invite */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="bg-blue-50 border-b border-blue-100 px-6 py-4 flex items-center gap-3">
            <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
              <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
              </svg>
            </div>
            <div>
              <h2 className="font-semibold text-gray-900">Teacher Invite</h2>
              <p className="text-xs text-gray-500">Teachers can view student usage stats</p>
            </div>
          </div>
          <div className="p-6">
            {teacherLink ? (
              <div className="space-y-4">
                {/* QR Code */}
                <div className="flex justify-center">
                  <div className="bg-white p-3 rounded-xl border-2 border-gray-100">
                    <img
                      src={qrApiUrl(teacherLink, 180)}
                      alt="Teacher invite QR code"
                      width={180}
                      height={180}
                      className="rounded"
                    />
                  </div>
                </div>
                {/* Link + Copy */}
                <div className="flex items-center gap-2 bg-gray-50 rounded-lg px-3 py-2">
                  <input
                    type="text"
                    readOnly
                    value={teacherLink}
                    className="flex-1 text-xs text-gray-500 bg-transparent border-none outline-none truncate"
                  />
                  <button
                    onClick={() => copyToClipboard(teacherLink, 'teacher')}
                    className={`flex-shrink-0 px-3 py-1.5 rounded-md text-xs font-medium transition-all ${
                      copiedKey === 'teacher'
                        ? 'bg-blue-500 text-white'
                        : 'bg-blue-600 text-white hover:bg-blue-700'
                    }`}
                  >
                    {copiedKey === 'teacher' ? 'Copied!' : 'Copy Link'}
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => { setRole('teacher'); handleGenerateLink() }}
                disabled={loading}
                className="w-full py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
              >
                {loading && role === 'teacher' ? 'Generating...' : 'Generate Teacher Link'}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* How it works */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
        <h3 className="font-semibold text-gray-900 mb-4">How it works</h3>
        <div className="grid sm:grid-cols-3 gap-4">
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold text-gray-600">1</div>
            <div>
              <p className="font-medium text-gray-900 text-sm">Share the link or QR</p>
              <p className="text-xs text-gray-500 mt-0.5">Show the QR code in class or send the link via email/LINE/Slack</p>
            </div>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold text-gray-600">2</div>
            <div>
              <p className="font-medium text-gray-900 text-sm">They sign in to Lecsy</p>
              <p className="text-xs text-gray-500 mt-0.5">Google or Apple sign-in. Takes 10 seconds.</p>
            </div>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold text-gray-600">3</div>
            <div>
              <p className="font-medium text-gray-900 text-sm">Automatically joined</p>
              <p className="text-xs text-gray-500 mt-0.5">They get Pro features and appear in your member list.</p>
            </div>
          </div>
        </div>
      </div>

      {/* Bulk CSV Invite */}
      <div className="mb-8">
        <BulkInviteUpload slug={slug} onInvitesCreated={refreshInvites} />
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700 mb-8">
          {error}
        </div>
      )}

      {/* Invite History */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <button
          onClick={() => setShowHistory(!showHistory)}
          className="w-full px-6 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors"
        >
          <h2 className="text-lg font-semibold text-gray-900">Invite History ({invites.length})</h2>
          <svg
            className={`w-5 h-5 text-gray-400 transition-transform ${showHistory ? 'rotate-180' : ''}`}
            fill="none" stroke="currentColor" viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {showHistory && invites.length > 0 && (
          <div className="border-t border-gray-200 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50">
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Role</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Created</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Status</th>
                  <th className="text-right px-6 py-3 font-medium text-gray-500">Actions</th>
                </tr>
              </thead>
              <tbody>
                {invites.map((invite) => {
                  const expired = isExpired(invite.expires_at)
                  return (
                    <tr key={invite.id} className="border-b border-gray-50">
                      <td className="px-6 py-3">
                        <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize ${
                          invite.role === 'teacher' ? 'bg-blue-100 text-blue-700' : 'bg-green-100 text-green-700'
                        }`}>
                          {invite.role}
                        </span>
                      </td>
                      <td className="px-6 py-3 text-gray-500">
                        {new Date(invite.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                      </td>
                      <td className="px-6 py-3">
                        {expired ? (
                          <span className="text-xs text-red-600 font-medium">Expired</span>
                        ) : (
                          <span className="text-xs text-amber-600 font-medium">Active</span>
                        )}
                      </td>
                      <td className="px-6 py-3 text-right space-x-3">
                        {expired && (
                          <button
                            onClick={() => handleRefreshInvite(invite.id)}
                            disabled={refreshingId === invite.id}
                            className="text-xs text-blue-600 hover:text-blue-800 disabled:opacity-50 font-medium"
                          >
                            {refreshingId === invite.id ? 'Refreshing...' : 'Refresh'}
                          </button>
                        )}
                        <button
                          onClick={() => handleCancelInvite(invite.id)}
                          disabled={cancellingId === invite.id}
                          className="text-xs text-red-600 hover:text-red-800 disabled:opacity-50"
                        >
                          {cancellingId === invite.id ? 'Removing...' : 'Remove'}
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  )
}
