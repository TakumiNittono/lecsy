import { createAdminClient } from '@/utils/supabase/admin'
import { requireOrgRole } from '@/utils/api/org-auth'
import { NextResponse, NextRequest } from 'next/server'

export const dynamic = 'force-dynamic'

/**
 * CSV export of all transcripts for the organization.
 * Filters by organization_id (post Week-1 cloud-sync model) — does NOT
 * fall back to user_id IN (members), so personal pre-membership recordings
 * never leak into a school's export.
 *
 * Only teacher+ can export. Pass ?q= for the same ILIKE filter as the page.
 */
export async function GET(
  req: NextRequest,
  { params }: { params: { slug: string } }
) {
  const auth = await requireOrgRole(params.slug, 'teacher')
  if (auth instanceof NextResponse) return auth

  const admin = createAdminClient()
  const { orgId, org } = auth

  const q = (req.nextUrl.searchParams.get('q') || '').trim()

  let query = admin
    .from('transcripts')
    .select('id, title, created_at, duration, language, user_id, word_count')
    .eq('organization_id', orgId)
    .order('created_at', { ascending: false })
    .limit(10000) // Hard cap so a single export never takes the function down

  if (q) {
    const escaped = q.replace(/[%_]/g, '\\$&')
    query = query.or(`title.ilike.%${escaped}%,content.ilike.%${escaped}%`)
  }

  const { data: transcripts, error } = await query
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  // Resolve emails (de-duped)
  const emailMap = new Map<string, string>()
  const userIds = [...new Set((transcripts || []).map((t) => t.user_id))]
  for (const uid of userIds) {
    const { data } = await admin.auth.admin.getUserById(uid)
    if (data?.user?.email) emailMap.set(uid, data.user.email)
  }

  // Build CSV — RFC 4180-ish escaping
  function csvCell(v: unknown): string {
    if (v == null) return ''
    const s = String(v)
    if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`
    return s
  }

  const rows: string[] = []
  rows.push(['id', 'user_email', 'title', 'created_at', 'duration_seconds', 'language', 'word_count'].join(','))
  for (const t of transcripts || []) {
    const dur =
      t.duration != null
        ? typeof t.duration === 'string'
          ? parseFloat(t.duration)
          : t.duration
        : ''
    rows.push(
      [
        csvCell(t.id),
        csvCell(emailMap.get(t.user_id) || ''),
        csvCell(t.title),
        csvCell(t.created_at),
        csvCell(dur),
        csvCell(t.language),
        csvCell(t.word_count),
      ].join(',')
    )
  }

  const csv = rows.join('\n')
  const ts = new Date().toISOString().slice(0, 10)
  const filename = `${org.slug}-transcripts-${ts}.csv`

  return new NextResponse(csv, {
    status: 200,
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Cache-Control': 'no-store',
    },
  })
}
