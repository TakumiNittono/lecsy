'use client'

import { useState } from 'react'

interface Invite {
  id: string
  email: string
  role: string
  token: string
  expires_at: string
  created_at: string
}

interface GeneratedLink {
  email: string
  url: string
}

interface Props {
  slug: string
  initialInvites: Invite[]
  appUrl: string
}

export default function InviteManager({ slug, initialInvites, appUrl }: Props) {
  const [invites, setInvites] = useState<Invite[]>(initialInvites)
  const [emailInput, setEmailInput] = useState('')
  const [role, setRole] = useState<'teacher' | 'student'>('student')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [generatedLinks, setGeneratedLinks] = useState<GeneratedLink[]>([])
  const [copiedId, setCopiedId] = useState<string | null>(null)
  const [cancellingId, setCancellingId] = useState<string | null>(null)

  async function copyToClipboard(text: string, id: string) {
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const textarea = document.createElement('textarea')
      textarea.value = text
      textarea.style.position = 'fixed'
      textarea.style.opacity = '0'
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand('copy')
      document.body.removeChild(textarea)
    }
    setCopiedId(id)
    setTimeout(() => setCopiedId(null), 2000)
  }

  async function handleCreateInvites() {
    const rawEmails = emailInput
      .split(/[\n,]+/)
      .map((e) => e.trim())
      .filter((e) => e.length > 0)

    if (rawEmails.length === 0) {
      setError('Please enter at least one email address.')
      return
    }

    setLoading(true)
    setError(null)
    setGeneratedLinks([])

    try {
      const res = await fetch(`/api/org/${slug}/invites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ emails: rawEmails, role }),
      })

      const data = await res.json()

      if (!res.ok) {
        setError(data.error || 'Failed to create invites.')
        return
      }

      // data.invites contains newly created invites
      const newInvites: Invite[] = data.invites || []
      const links: GeneratedLink[] = newInvites.map((inv: Invite) => ({
        email: inv.email,
        url: `${appUrl}/invite/${inv.token}`,
      }))

      setGeneratedLinks(links)
      setInvites((prev) => [...newInvites, ...prev])
      setEmailInput('')
    } catch {
      setError('Network error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  async function handleCancelInvite(id: string) {
    if (!confirm('Are you sure you want to cancel this invite?')) return

    setCancellingId(id)
    try {
      const res = await fetch(`/api/org/${slug}/invites/${id}`, {
        method: 'DELETE',
      })

      if (!res.ok) {
        const data = await res.json()
        alert(data.error || 'Failed to cancel invite.')
        return
      }

      setInvites((prev) => prev.filter((inv) => inv.id !== id))
    } catch {
      alert('Network error. Please try again.')
    } finally {
      setCancellingId(null)
    }
  }

  function isExpired(expiresAt: string) {
    return new Date(expiresAt) < new Date()
  }

  function formatDate(dateStr: string) {
    return new Date(dateStr).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  const roleBadgeClass: Record<string, string> = {
    teacher: 'bg-blue-100 text-blue-700',
    student: 'bg-green-100 text-green-700',
    admin: 'bg-purple-100 text-purple-700',
  }

  return (
    <>
      {/* Page Title */}
      <h1 className="text-2xl font-bold text-gray-900 mb-8">Invite Members</h1>

      {/* Section 1: Create Invites */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Create Invites</h2>

        <div className="space-y-4">
          <div>
            <label htmlFor="emails" className="block text-sm font-medium text-gray-700 mb-1">
              Email Addresses
            </label>
            <textarea
              id="emails"
              rows={4}
              className="w-full rounded-lg border border-gray-300 px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none transition-colors resize-none"
              placeholder="Enter emails, one per line or comma-separated"
              value={emailInput}
              onChange={(e) => setEmailInput(e.target.value)}
            />
          </div>

          <div className="flex flex-wrap items-end gap-4">
            <div>
              <label htmlFor="role" className="block text-sm font-medium text-gray-700 mb-1">
                Role
              </label>
              <select
                id="role"
                value={role}
                onChange={(e) => setRole(e.target.value as 'teacher' | 'student')}
                className="rounded-lg border border-gray-300 px-4 py-2.5 text-sm text-gray-900 bg-white focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none transition-colors"
              >
                <option value="student">Student</option>
                <option value="teacher">Teacher</option>
              </select>
            </div>

            <button
              onClick={handleCreateInvites}
              disabled={loading}
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? (
                <>
                  <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Generating...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                  </svg>
                  Generate Invite Links
                </>
              )}
            </button>
          </div>

          {error && (
            <div className="rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          )}

          {generatedLinks.length > 0 && (
            <div className="mt-4 space-y-3">
              <h3 className="text-sm font-medium text-gray-700">Generated Invite Links</h3>
              <div className="space-y-2">
                {generatedLinks.map((link) => (
                  <div
                    key={link.email}
                    className="flex items-center gap-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-3"
                  >
                    <span className="text-sm text-gray-700 font-medium min-w-0 truncate flex-shrink-0">
                      {link.email}
                    </span>
                    <input
                      type="text"
                      readOnly
                      value={link.url}
                      className="flex-1 min-w-0 text-xs text-gray-500 bg-transparent border-none outline-none truncate"
                    />
                    <button
                      onClick={() => copyToClipboard(link.url, `gen-${link.email}`)}
                      className={`flex-shrink-0 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                        copiedId === `gen-${link.email}`
                          ? 'bg-green-100 text-green-700'
                          : 'bg-white border border-gray-300 text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      {copiedId === `gen-${link.email}` ? (
                        <>
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                          </svg>
                          Copied!
                        </>
                      ) : (
                        <>
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                          </svg>
                          Copy
                        </>
                      )}
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Section 2: Pending Invites */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Pending Invites</h2>
        </div>

        {invites.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100">
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Email</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Role</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Expires</th>
                  <th className="text-left px-6 py-3 font-medium text-gray-500">Status</th>
                  <th className="text-right px-6 py-3 font-medium text-gray-500">Actions</th>
                </tr>
              </thead>
              <tbody>
                {invites.map((invite) => {
                  const expired = isExpired(invite.expires_at)
                  const inviteUrl = `${appUrl}/invite/${invite.token}`

                  return (
                    <tr key={invite.id} className="border-b border-gray-50 hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-3 text-gray-900 font-medium">{invite.email}</td>
                      <td className="px-6 py-3">
                        <span
                          className={`inline-block px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize ${
                            roleBadgeClass[invite.role] || 'bg-gray-100 text-gray-700'
                          }`}
                        >
                          {invite.role}
                        </span>
                      </td>
                      <td className="px-6 py-3">
                        {expired ? (
                          <span className="text-red-600 font-medium">Expired</span>
                        ) : (
                          <span className="text-gray-500">{formatDate(invite.expires_at)}</span>
                        )}
                      </td>
                      <td className="px-6 py-3">
                        {expired ? (
                          <span className="inline-block px-2.5 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-700">
                            Expired
                          </span>
                        ) : (
                          <span className="inline-block px-2.5 py-0.5 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-700">
                            Pending
                          </span>
                        )}
                      </td>
                      <td className="px-6 py-3">
                        <div className="flex items-center justify-end gap-2">
                          {!expired && (
                            <button
                              onClick={() => copyToClipboard(inviteUrl, invite.id)}
                              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                                copiedId === invite.id
                                  ? 'bg-green-100 text-green-700'
                                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                              }`}
                            >
                              {copiedId === invite.id ? (
                                <>
                                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                  </svg>
                                  Copied!
                                </>
                              ) : (
                                <>
                                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                                  </svg>
                                  Copy Link
                                </>
                              )}
                            </button>
                          )}
                          <button
                            onClick={() => handleCancelInvite(invite.id)}
                            disabled={cancellingId === invite.id}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium text-red-700 bg-red-50 hover:bg-red-100 disabled:opacity-50 transition-colors"
                          >
                            {cancellingId === invite.id ? (
                              <>
                                <svg className="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
                                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                                </svg>
                                Cancelling...
                              </>
                            ) : (
                              <>
                                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                                </svg>
                                Cancel
                              </>
                            )}
                          </button>
                        </div>
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
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
            <p className="text-gray-500">No pending invites</p>
            <p className="text-sm text-gray-400 mt-1">Create invites above to get started</p>
          </div>
        )}
      </div>
    </>
  )
}
