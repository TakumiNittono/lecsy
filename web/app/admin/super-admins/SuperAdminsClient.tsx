'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

interface Row {
  email: string
  note: string | null
  created_at: string
}

interface Props {
  rows: Row[]
  currentUserEmail: string
}

export default function SuperAdminsClient({ rows: initialRows, currentUserEmail }: Props) {
  const router = useRouter()
  const [rows, setRows] = useState(initialRows)
  const [email, setEmail] = useState('')
  const [note, setNote] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      const res = await fetch('/api/admin/super-admins', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, note }),
      })
      const data = await res.json()
      if (!res.ok) {
        setError(data.error ?? 'failed')
        return
      }
      setEmail('')
      setNote('')
      // Refetch from server to get authoritative state
      router.refresh()
      // Optimistic local update so the row appears immediately
      setRows((prev) => [
        ...prev,
        { email: data.email, note: note || null, created_at: new Date().toISOString() },
      ])
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setSubmitting(false)
    }
  }

  async function handleRemove(target: string) {
    if (!confirm(`Remove ${target} as super admin?`)) return
    setBusy(target)
    setError(null)
    try {
      const res = await fetch(`/api/admin/super-admins?email=${encodeURIComponent(target)}`, {
        method: 'DELETE',
      })
      const data = await res.json()
      if (!res.ok) {
        setError(data.error ?? 'failed')
        return
      }
      setRows((prev) => prev.filter((r) => r.email !== target))
      router.refresh()
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="space-y-6">
      <form onSubmit={handleAdd} className="bg-white border border-gray-200 rounded-xl p-5 space-y-3">
        <h2 className="text-base font-semibold text-gray-900">Add super admin</h2>
        <div className="flex flex-col sm:flex-row gap-2">
          <input
            type="email"
            required
            placeholder="email@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            type="text"
            placeholder="note (optional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            disabled={submitting || !email}
            className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {submitting ? 'Adding…' : 'Add'}
          </button>
        </div>
        {error && (
          <p className="text-sm text-red-600">{error}</p>
        )}
        <p className="text-xs text-gray-500">
          Super admins can create organizations, grant ownership, and manage any org via the
          <code className="mx-1 px-1 py-0.5 bg-gray-100 rounded">/admin</code> dashboard. Add only
          people you fully trust.
        </p>
      </form>

      <div className="bg-white border border-gray-200 rounded-xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-left text-gray-600 text-xs uppercase tracking-wide">
            <tr>
              <th className="px-5 py-3">Email</th>
              <th className="px-5 py-3">Note</th>
              <th className="px-5 py-3">Added</th>
              <th className="px-5 py-3 w-24"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {rows.length === 0 && (
              <tr>
                <td colSpan={4} className="px-5 py-6 text-center text-gray-500">
                  No super admins yet.
                </td>
              </tr>
            )}
            {rows.map((row) => {
              const isSelf = row.email === currentUserEmail.toLowerCase()
              return (
                <tr key={row.email}>
                  <td className="px-5 py-3 font-medium text-gray-900">
                    {row.email}
                    {isSelf && (
                      <span className="ml-2 px-2 py-0.5 text-xs bg-blue-100 text-blue-700 rounded">
                        you
                      </span>
                    )}
                  </td>
                  <td className="px-5 py-3 text-gray-600">{row.note ?? '—'}</td>
                  <td className="px-5 py-3 text-gray-500 text-xs">
                    {new Date(row.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-5 py-3 text-right">
                    {!isSelf && (
                      <button
                        onClick={() => handleRemove(row.email)}
                        disabled={busy === row.email}
                        className="text-sm text-red-600 hover:text-red-800 font-medium disabled:opacity-50"
                      >
                        {busy === row.email ? '…' : 'Remove'}
                      </button>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
