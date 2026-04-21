// /admin/invite-cards/[slug] — print-ready card sheet for classroom pilots.
//
// Kim's May 1-6 FMCC rollout needs one tangible artifact: a stack of cards,
// one per student, with a QR code that opens the iPhone app directly
// (`lecsy://invite?code=XXX`, no Safari bounce). This page server-renders
// that stack in a print-optimized grid — open it in Chrome, Cmd+P, done.
//
// Access: auth-gated like the rest of /admin. We fetch codes with the
// admin client so RLS doesn't hide unused rows from the operator.

import { notFound, redirect } from 'next/navigation'
import QRCode from 'qrcode'
import { createAdminClient } from '@/utils/supabase/admin'
import { getOrgMembership } from '@/utils/api/org-auth'

export const dynamic = 'force-dynamic'

interface PageProps {
  params: { slug: string }
  searchParams: {
    /** include already-redeemed codes too (for re-prints). Off by default. */
    all?: string
  }
}

interface CardRow {
  code: string
  label: string | null
  qr: string // inline SVG
}

async function fetchCards(orgId: string, includeUsed: boolean): Promise<CardRow[]> {
  const supabase = createAdminClient()
  let query = supabase
    .from('organization_invite_codes')
    .select('code, label, used_at')
    .eq('org_id', orgId)
    .order('label', { ascending: true, nullsFirst: false })
    .order('created_at', { ascending: true })
  if (!includeUsed) {
    query = query.is('used_at', null)
  }
  const { data, error } = await query
  if (error) {
    console.error('fetchCards failed:', error)
    return []
  }
  const rows = data || []

  // Generate inline SVG QRs for each code. Server-side so no flash of
  // missing art + no client bundle cost.
  const out: CardRow[] = []
  for (const row of rows) {
    const url = `lecsy://invite?code=${encodeURIComponent(row.code)}`
    const qr = await QRCode.toString(url, {
      type: 'svg',
      errorCorrectionLevel: 'M',
      margin: 1,
      width: 240,
      color: { dark: '#0F172A', light: '#FFFFFF' },
    })
    out.push({ code: row.code, label: row.label, qr })
  }
  return out
}

export default async function PrintInviteCardsPage({ params, searchParams }: PageProps) {
  // Auth: only owner/admin of this org can print cards.
  const membership = await getOrgMembership(params.slug)
  if (!membership) redirect('/app')
  if (membership.role !== 'owner' && membership.role !== 'admin') {
    redirect(`/org/${params.slug}`)
  }

  const includeUsed = searchParams.all === '1'
  const cards = await fetchCards(membership.orgId, includeUsed)
  if (cards.length === 0) notFound()

  return (
    <>
      {/* Print-targeted styles — screen view is just a preview. */}
      <style>{`
        @page { size: letter; margin: 0.4in; }
        @media print {
          .no-print { display: none !important; }
          .card { break-inside: avoid; }
        }
        .card-grid {
          display: grid;
          grid-template-columns: repeat(2, 1fr);
          gap: 12px;
        }
        @media (min-width: 900px) {
          .card-grid { grid-template-columns: repeat(2, 1fr); }
        }
      `}</style>

      <main className="min-h-screen bg-gray-100 py-8 print:bg-white print:py-0">
        <div className="max-w-4xl mx-auto px-6 print:px-0">
          <header className="no-print mb-6 flex items-center justify-between">
            <div>
              <h1 className="text-xl font-bold text-gray-900">
                {membership.org.name} — invite cards
              </h1>
              <p className="text-sm text-gray-600 mt-1">
                {cards.length} {includeUsed ? 'total' : 'unused'} code
                {cards.length !== 1 ? 's' : ''}. <kbd className="px-1.5 py-0.5 text-xs bg-gray-200 rounded">⌘</kbd>+
                <kbd className="px-1.5 py-0.5 text-xs bg-gray-200 rounded">P</kbd> to print.
              </p>
            </div>
            <div className="text-xs text-gray-500 text-right">
              QR scheme: <code className="bg-white px-1 py-0.5 rounded">lecsy://invite?code=…</code>
              <br />
              iOS Camera → tap → app opens, code auto-redeemed.
            </div>
          </header>

          <div className="card-grid">
            {cards.map((c) => (
              <div
                key={c.code}
                className="card bg-white border border-gray-300 rounded-2xl p-5 flex flex-col items-center"
              >
                <div className="text-xs font-semibold tracking-wider uppercase text-blue-700 mb-1">
                  Welcome to Lecsy
                </div>
                <div className="text-[10px] text-gray-500 mb-3">
                  {membership.org.name} · {c.label || 'Student'}
                </div>
                <div
                  className="w-[180px] h-[180px]"
                  // The SVG from qrcode library is fully self-contained.
                  dangerouslySetInnerHTML={{ __html: c.qr }}
                />
                <div className="mt-3 text-center">
                  <div className="text-[10px] text-gray-500 mb-0.5">Your code</div>
                  <div className="text-xl font-bold font-mono tracking-[0.3em] text-gray-900">
                    {c.code}
                  </div>
                </div>
                <div className="mt-3 text-[10px] text-gray-600 text-center leading-relaxed px-2">
                  Scan with iPhone camera → tap the Lecsy banner.
                  <br />
                  Or open Lecsy, tap <strong>Have an invite code?</strong>, type the 6 digits.
                </div>
              </div>
            ))}
          </div>
        </div>
      </main>
    </>
  )
}
