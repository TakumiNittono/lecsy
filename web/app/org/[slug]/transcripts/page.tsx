import { createAdminClient } from '@/utils/supabase/admin'
import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

interface SearchParams {
  q?: string
  page?: string
}

const PAGE_SIZE = 50

export default async function OrgTranscriptsPage({
  params,
  searchParams,
}: {
  params: { slug: string }
  searchParams: SearchParams
}) {
  const membership = await getOrgMembership(params.slug)
  if (!membership || membership.role === 'student') {
    redirect('/app')
  }

  const admin = createAdminClient()
  const { orgId } = membership

  const q = (searchParams.q || '').trim()
  const page = Math.max(1, parseInt(searchParams.page || '1', 10) || 1)
  const offset = (page - 1) * PAGE_SIZE

  // Filter strictly by organization_id (post Week-1 cloud-sync model).
  // We deliberately do NOT fall back to user_id IN (members) — that would
  // leak personal pre-membership recordings into the org dashboard.
  let query = admin
    .from('transcripts')
    .select('id, title, content, created_at, duration, language, user_id', {
      count: 'exact',
    })
    .eq('organization_id', orgId)
    .order('created_at', { ascending: false })
    .range(offset, offset + PAGE_SIZE - 1)

  if (q) {
    // Simple ILIKE for now. When transcripts > ~50K consider adding a
    // tsvector column + GIN index in a migration.
    const escaped = q.replace(/[%_]/g, '\\$&')
    query = query.or(`title.ilike.%${escaped}%,content.ilike.%${escaped}%`)
  }

  const { data: transcripts, count } = await query

  // Resolve emails for the visible page only
  const emailMap = new Map<string, string>()
  const userIds = [...new Set((transcripts || []).map((t) => t.user_id))]
  for (const uid of userIds) {
    const { data } = await admin.auth.admin.getUserById(uid)
    if (data?.user?.email) emailMap.set(uid, data.user.email)
  }

  const total = count ?? 0
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  function snippet(content: string | null, query: string): string {
    if (!content) return ''
    if (!query) return content.slice(0, 160) + (content.length > 160 ? '…' : '')
    const idx = content.toLowerCase().indexOf(query.toLowerCase())
    if (idx < 0) return content.slice(0, 160) + (content.length > 160 ? '…' : '')
    const start = Math.max(0, idx - 60)
    const end = Math.min(content.length, idx + query.length + 100)
    return (start > 0 ? '…' : '') + content.slice(start, end) + (end < content.length ? '…' : '')
  }

  return (
    <div className="px-6 lg:px-10 py-8">
      <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Transcripts</h1>
          <p className="text-sm text-gray-500 mt-1">
            All lecture transcripts from your organization members. Audio is never uploaded — only the text.
          </p>
        </div>
        <a
          href={`/api/org/${params.slug}/transcripts/export${q ? `?q=${encodeURIComponent(q)}` : ''}`}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white text-gray-700 text-sm font-medium rounded-lg border border-gray-300 hover:bg-gray-50"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M7 10l5 5 5-5M12 15V3" />
          </svg>
          Export CSV
        </a>
      </div>

      {/* Search form (GET so the URL is shareable) */}
      <form method="GET" className="mb-6">
        <div className="flex gap-2">
          <input
            type="search"
            name="q"
            defaultValue={q}
            placeholder="Search title or transcript text…"
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            className="px-5 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700"
          >
            Search
          </button>
          {q && (
            <Link
              href={`/org/${params.slug}/transcripts`}
              className="px-4 py-2 text-gray-600 text-sm font-medium hover:text-gray-900"
            >
              Clear
            </Link>
          )}
        </div>
      </form>

      <p className="text-sm text-gray-500 mb-4">
        {total} {total === 1 ? 'transcript' : 'transcripts'}
        {q && <> matching &ldquo;{q}&rdquo;</>}
      </p>

      {/* List */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 divide-y divide-gray-100">
        {transcripts && transcripts.length > 0 ? (
          transcripts.map((t) => {
            const d = t.duration != null ? (typeof t.duration === 'string' ? parseFloat(t.duration) : t.duration) : 0
            const mins = Math.floor(d / 60)
            const secs = Math.floor(d % 60)
            const durationStr = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`
            const email = emailMap.get(t.user_id) || t.user_id.slice(0, 8) + '…'
            return (
              <div key={t.id} className="p-5 hover:bg-gray-50 transition-colors">
                <div className="flex flex-wrap items-baseline justify-between gap-2 mb-2">
                  <h3 className="font-semibold text-gray-900">{t.title || 'Untitled'}</h3>
                  <div className="flex items-center gap-3 text-xs text-gray-500">
                    <Link
                      href={`/org/${params.slug}/students/${t.user_id}`}
                      className="text-blue-600 hover:underline"
                    >
                      {email}
                    </Link>
                    <span>·</span>
                    <span>{new Date(t.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
                    <span>·</span>
                    <span>{durationStr}</span>
                    {t.language && (
                      <>
                        <span>·</span>
                        <span className="px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 uppercase">{t.language}</span>
                      </>
                    )}
                  </div>
                </div>
                <p className="text-sm text-gray-600 leading-relaxed">{snippet(t.content, q)}</p>
              </div>
            )
          })
        ) : (
          <div className="text-center py-16">
            <p className="text-gray-500">{q ? 'No transcripts match your search.' : 'No transcripts yet.'}</p>
            <p className="text-sm text-gray-400 mt-1">
              Transcripts will appear here once organization members start recording with cloud sync enabled.
            </p>
          </div>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-6 flex justify-center gap-2">
          {page > 1 && (
            <Link
              href={`/org/${params.slug}/transcripts?${new URLSearchParams({ ...(q ? { q } : {}), page: String(page - 1) })}`}
              className="px-4 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Previous
            </Link>
          )}
          <span className="px-4 py-2 text-sm text-gray-600">
            Page {page} of {totalPages}
          </span>
          {page < totalPages && (
            <Link
              href={`/org/${params.slug}/transcripts?${new URLSearchParams({ ...(q ? { q } : {}), page: String(page + 1) })}`}
              className="px-4 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Next
            </Link>
          )}
        </div>
      )}
    </div>
  )
}
