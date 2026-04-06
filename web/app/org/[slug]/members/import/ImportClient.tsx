'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

interface Row {
  email: string
  role: 'student' | 'teacher' | 'admin'
  display_name?: string
}

interface ImportResult {
  successes: Array<{ email: string; status: string }>
  failures: Array<{ row: number; email: string; reason: string }>
  summary: { total: number; ok: number; ng: number }
}

export default function ImportClient({ orgId, slug }: { orgId: string; slug: string }) {
  const router = useRouter()
  const [rows, setRows] = useState<Row[]>([])
  const [parseError, setParseError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [result, setResult] = useState<ImportResult | null>(null)

  function handleFile(file: File) {
    setParseError(null)
    setResult(null)
    const reader = new FileReader()
    reader.onload = () => {
      try {
        const text = String(reader.result)
        const parsed = parseCsv(text)
        setRows(parsed)
      } catch (e: any) {
        setParseError(e.message ?? 'parse_error')
        setRows([])
      }
    }
    reader.readAsText(file)
  }

  function parseCsv(text: string): Row[] {
    const lines = text.split(/\r?\n/).filter((l) => l.trim().length > 0)
    if (lines.length < 2) throw new Error('CSV must have a header row and at least one data row')
    const header = lines[0].split(',').map((h) => h.trim().toLowerCase())
    const emailIdx = header.indexOf('email')
    const roleIdx = header.indexOf('role')
    const nameIdx = header.indexOf('display_name')
    if (emailIdx === -1) throw new Error('CSV must have an "email" column')

    const out: Row[] = []
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(',').map((c) => c.trim())
      const email = cols[emailIdx]
      if (!email) continue
      const role = (roleIdx >= 0 ? cols[roleIdx] : 'student') as Row['role']
      const display_name = nameIdx >= 0 ? cols[nameIdx] : undefined
      out.push({ email, role: role || 'student', display_name })
    }
    if (out.length > 1000) throw new Error('Maximum 1000 rows per upload')
    return out
  }

  async function submit() {
    setSubmitting(true)
    setResult(null)
    try {
      const res = await fetch(`/api/org/${slug}/members/import`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ org_id: orgId, rows }),
      })
      const data = await res.json()
      if (!res.ok) {
        setParseError(data.error ?? 'submit_failed')
      } else {
        setResult(data)
      }
    } catch (e: any) {
      setParseError(e.message ?? 'network_error')
    } finally {
      setSubmitting(false)
    }
  }

  function downloadFailures() {
    if (!result) return
    const csv = ['email,row,reason', ...result.failures.map((f) => `${f.email},${f.row},${f.reason}`)].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'import_failures.csv'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div>
      <div className="border-2 border-dashed border-gray-300 rounded p-8 text-center mb-4">
        <input
          type="file"
          accept=".csv,text/csv"
          onChange={(e) => e.target.files?.[0] && handleFile(e.target.files[0])}
          className="block mx-auto"
        />
        <p className="text-xs text-gray-500 mt-2">Drag a CSV file or click to select</p>
      </div>

      {parseError && (
        <div className="mb-4 p-3 bg-red-50 text-red-700 rounded">{parseError}</div>
      )}

      {rows.length > 0 && !result && (
        <div className="mb-4">
          <div className="flex justify-between items-center mb-2">
            <strong>Preview ({rows.length} rows)</strong>
            <button
              onClick={submit}
              disabled={submitting}
              className="px-4 py-2 bg-blue-600 text-white rounded disabled:opacity-50"
            >
              {submitting ? 'Importing…' : `Import ${rows.length} members`}
            </button>
          </div>
          <div className="max-h-64 overflow-y-auto border rounded">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 sticky top-0">
                <tr>
                  <th className="px-2 py-1 text-left">Email</th>
                  <th className="px-2 py-1 text-left">Role</th>
                  <th className="px-2 py-1 text-left">Name</th>
                </tr>
              </thead>
              <tbody>
                {rows.slice(0, 100).map((r, i) => (
                  <tr key={i} className="border-t">
                    <td className="px-2 py-1">{r.email}</td>
                    <td className="px-2 py-1">{r.role}</td>
                    <td className="px-2 py-1">{r.display_name ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {rows.length > 100 && <p className="text-xs text-gray-500 p-2">…{rows.length - 100} more</p>}
          </div>
        </div>
      )}

      {result && (
        <div className="mb-4 space-y-3">
          <div className="p-4 bg-green-50 text-green-800 rounded">
            ✅ {result.summary.ok} added · ❌ {result.summary.ng} failed · Total {result.summary.total}
          </div>
          {result.failures.length > 0 && (
            <div>
              <div className="flex justify-between items-center mb-2">
                <strong>Failures</strong>
                <button onClick={downloadFailures} className="text-sm text-blue-600 hover:underline">
                  Download failures CSV
                </button>
              </div>
              <div className="max-h-48 overflow-y-auto border rounded">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 sticky top-0">
                    <tr><th className="px-2 py-1 text-left">Row</th><th className="px-2 py-1 text-left">Email</th><th className="px-2 py-1 text-left">Reason</th></tr>
                  </thead>
                  <tbody>
                    {result.failures.map((f, i) => (
                      <tr key={i} className="border-t">
                        <td className="px-2 py-1">{f.row}</td>
                        <td className="px-2 py-1">{f.email}</td>
                        <td className="px-2 py-1 text-red-600">{f.reason}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
          <button
            onClick={() => router.push(`/org/${slug}/members`)}
            className="px-4 py-2 bg-gray-200 rounded"
          >
            Back to members
          </button>
        </div>
      )}
    </div>
  )
}
