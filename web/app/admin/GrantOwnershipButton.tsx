'use client'

import { useState } from 'react'

export default function GrantOwnershipButton({ orgId, orgName }: { orgId: string; orgName: string }) {
  const [open, setOpen] = useState(false)
  const [email, setEmail] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    setSubmitting(true)
    setError(null)
    setMessage(null)
    try {
      const res = await fetch('/api/admin/grant-ownership', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ org_id: orgId, email }),
      })
      const data = await res.json()
      if (!res.ok) {
        setError(data.error ?? 'failed')
      } else {
        setMessage(`Owner ${data.action}. The user becomes active on next login.`)
        setEmail('')
      }
    } catch (e: any) {
      setError(e.message ?? 'network_error')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="text-sm text-orange-600 hover:text-orange-800"
      >
        Grant owner
      </button>

      {open && (
        <div
          className="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
          onClick={() => setOpen(false)}
        >
          <div
            className="bg-white rounded-xl p-6 max-w-md w-full mx-4"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-lg font-semibold mb-2">Grant ownership</h3>
            <p className="text-sm text-gray-600 mb-4">
              Add or promote an email to <strong>owner</strong> of <strong>{orgName}</strong>.
            </p>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="owner@school.edu"
              className="w-full px-3 py-2 border border-gray-300 rounded mb-3"
              autoFocus
            />
            {error && <div className="text-sm text-red-600 mb-2">{error}</div>}
            {message && <div className="text-sm text-green-600 mb-2">{message}</div>}
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setOpen(false)}
                className="px-4 py-2 text-gray-600 hover:text-gray-900"
              >
                Close
              </button>
              <button
                onClick={submit}
                disabled={!email || submitting}
                className="px-4 py-2 bg-orange-600 text-white rounded disabled:opacity-50"
              >
                {submitting ? 'Granting…' : 'Grant ownership'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
