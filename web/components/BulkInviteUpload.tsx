'use client'

import { useState, useRef } from 'react'

interface ParsedRow {
  email: string
  role: string
  valid: boolean
}

interface Props {
  slug: string
  onMembersAdded: () => void
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default function BulkInviteUpload({ slug, onMembersAdded }: Props) {
  const [rows, setRows] = useState<ParsedRow[]>([])
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState<{ success: number; skipped: string[]; errors: string[] } | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  function parseCSV(text: string): ParsedRow[] {
    const lines = text.split('\n').map((l) => l.trim()).filter(Boolean)
    const parsed: ParsedRow[] = []

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      // Skip header row
      if (i === 0 && /email/i.test(line)) continue

      const parts = line.split(/[,\t]/).map((p) => p.trim().replace(/^["']|["']$/g, ''))
      const email = parts[0]?.toLowerCase() || ''
      const role = parts[1]?.toLowerCase() || 'student'
      const validRole = ['student', 'teacher', 'admin'].includes(role) ? role : 'student'

      parsed.push({
        email,
        role: validRole,
        valid: EMAIL_REGEX.test(email),
      })
    }
    return parsed
  }

  function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setResult(null)

    const reader = new FileReader()
    reader.onload = (ev) => {
      const text = ev.target?.result as string
      setRows(parseCSV(text))
    }
    reader.readAsText(file)
  }

  async function handleSend() {
    const validRows = rows.filter((r) => r.valid)
    if (validRows.length === 0) return

    setSending(true)
    setResult(null)

    // Group by role
    const byRole = new Map<string, string[]>()
    for (const row of validRows) {
      const list = byRole.get(row.role) || []
      list.push(row.email)
      byRole.set(row.role, list)
    }

    let totalSuccess = 0
    const allSkipped: string[] = []
    const errors: string[] = []

    for (const [role, emails] of byRole) {
      try {
        const res = await fetch(`/api/org/${slug}/invites`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ emails, role }),
        })
        const data = await res.json()
        if (res.ok) {
          totalSuccess += data.added?.length || 0
          if (data.skipped?.length > 0) {
            allSkipped.push(...data.skipped)
          }
        } else {
          errors.push(data.error || `Failed for ${role}s`)
        }
      } catch {
        errors.push(`Network error for ${role}s`)
      }
    }

    setResult({ success: totalSuccess, skipped: allSkipped, errors })
    if (totalSuccess > 0) {
      onMembersAdded()
    }
    setSending(false)
  }

  function handleClear() {
    setRows([])
    setResult(null)
    if (fileRef.current) fileRef.current.value = ''
  }

  const validCount = rows.filter((r) => r.valid).length
  const invalidCount = rows.filter((r) => !r.valid).length

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h3 className="font-semibold text-gray-900 mb-1">Bulk Add via CSV</h3>
      <p className="text-xs text-gray-500 mb-4">
        Upload a CSV file with columns: <code className="bg-gray-100 px-1 rounded">email,role</code> (role is optional, defaults to student)
      </p>

      {rows.length === 0 ? (
        <div>
          <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-400 hover:bg-blue-50/50 transition-colors">
            <svg className="w-8 h-8 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            <span className="text-sm text-gray-500">Click to upload CSV</span>
            <input
              ref={fileRef}
              type="file"
              accept=".csv,.txt,.tsv"
              onChange={handleFile}
              className="hidden"
            />
          </label>
        </div>
      ) : (
        <div>
          {/* Summary */}
          <div className="flex items-center gap-4 mb-4">
            <span className="text-sm text-gray-700">
              <span className="font-semibold text-green-600">{validCount}</span> valid
            </span>
            {invalidCount > 0 && (
              <span className="text-sm text-red-500 font-medium">
                {invalidCount} invalid
              </span>
            )}
            <button
              onClick={handleClear}
              className="text-xs text-gray-400 hover:text-gray-600 ml-auto"
            >
              Clear
            </button>
          </div>

          {/* Preview table */}
          <div className="max-h-48 overflow-y-auto border border-gray-200 rounded-lg mb-4">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-gray-50">
                <tr>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Email</th>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Role</th>
                  <th className="text-left px-3 py-2 font-medium text-gray-500 w-16">Valid</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr key={i} className={`border-t border-gray-50 ${!row.valid ? 'bg-red-50' : ''}`}>
                    <td className="px-3 py-1.5 text-gray-700">{row.email}</td>
                    <td className="px-3 py-1.5 capitalize text-gray-500">{row.role}</td>
                    <td className="px-3 py-1.5">
                      {row.valid ? (
                        <span className="text-green-500">OK</span>
                      ) : (
                        <span className="text-red-500">No</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Result message */}
          {result && (
            <div className={`rounded-lg px-4 py-3 text-sm mb-4 ${
              result.errors.length > 0
                ? 'bg-amber-50 border border-amber-200 text-amber-700'
                : 'bg-green-50 border border-green-200 text-green-700'
            }`}>
              {result.success > 0 && <p>{result.success} members added successfully.</p>}
              {result.skipped.length > 0 && <p>Skipped (already members): {result.skipped.join(', ')}</p>}
              {result.errors.map((err, i) => <p key={i}>{err}</p>)}
            </div>
          )}

          {/* Send button */}
          <button
            onClick={handleSend}
            disabled={sending || validCount === 0}
            className="w-full py-2.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            {sending ? 'Adding members...' : `Add ${validCount} members`}
          </button>
        </div>
      )}
    </div>
  )
}
