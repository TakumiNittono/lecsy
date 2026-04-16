import { getOrgMembership } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { Fraunces } from 'next/font/google'
import PrintButton from '@/components/PrintButton'

const fraunces = Fraunces({ subsets: ['latin'], variable: '--font-display', display: 'swap' })

export const dynamic = 'force-dynamic'

export const metadata = {
  title: 'Setup guide',
  robots: { index: false, follow: false },
}

/**
 * Printable, school-name-interpolated setup guide. Chrome Print → Save as PDF.
 * Target: ≤3 US Letter pages, self-contained, readable at 100% zoom.
 */
export default async function OnboardingGuide({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)
  if (!membership || membership.role === 'student') redirect('/app')

  const { org, userEmail } = membership
  const settings = (org.settings ?? {}) as Record<string, any>
  const displayName: string = settings.display_name ?? org.name
  const institutionFull: string = settings.institution_full ?? org.name

  const trialDate = org.trial_ends_at
    ? new Date(org.trial_ends_at).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    : null

  const today = new Date().toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })

  return (
    <div className={`${fraunces.variable} bg-white text-[#0B1E3F]`}>
      <style>{`
        @page { size: Letter; margin: 0.55in; }
        @media print {
          html, body { background: #ffffff !important; }
          [data-dashboard] header, [data-dashboard] aside, .no-print { display: none !important; }
          .guide-container { max-width: 100% !important; padding: 0 !important; box-shadow: none !important; }
          .page-break { break-after: page; page-break-after: always; }
        }
        @media screen {
          .guide-container { max-width: 780px; margin: 2rem auto; padding: 2.5rem; box-shadow: 0 4px 24px rgba(11,30,63,0.08); border-radius: 12px; background: white; }
        }
        .guide-container h1, .guide-container h2, .guide-container h3 {
          font-family: var(--font-display), Georgia, serif;
          color: #0B1E3F;
        }
      `}</style>

      <div className="bg-[#F7F5F1] min-h-screen print:bg-white print:min-h-0">
        {/* Screen-only toolbar */}
        <div className="no-print max-w-[780px] mx-auto px-8 pt-8 pb-4 flex items-center justify-between">
          <Link
            href={`/org/${params.slug}`}
            className="inline-flex items-center gap-2 text-sm text-[#4A5B74] hover:text-[#0B1E3F]"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to dashboard
          </Link>
          <PrintButton />
        </div>

        <article className="guide-container font-serif">
          {/* HEADER */}
          <header className="flex items-baseline justify-between border-b-2 border-[#0B1E3F] pb-4 mb-8">
            <div>
              <div className="font-[family-name:var(--font-display)] text-2xl font-semibold leading-none">lecsy</div>
              <div className="text-xs text-[#8A9BB5] mt-1 uppercase tracking-[0.18em]">
                Setup guide · Prepared for {displayName}
              </div>
            </div>
            {org.logo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={org.logo_url} alt={`${displayName} logo`} className="h-10 w-auto max-w-[180px] object-contain" />
            ) : (
              <div className="text-right text-xs text-[#4A5B74]">
                {today}
              </div>
            )}
          </header>

          {/* COVER */}
          <section className="mb-10">
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-2">
              Welcome
            </p>
            <h1 className="font-[family-name:var(--font-display)] text-[36px] leading-[1.1] font-semibold mb-4">
              {displayName} is live on Lecsy.
            </h1>
            <p className="text-[14px] text-[#4A5B74] leading-relaxed max-w-[6in]">
              This is a self-contained reference you can hand to faculty, IT, or a program
              coordinator. Three sections: what your teachers need to do, what your students need
              to do, and what you as admin can do from the dashboard.
              {trialDate && (
                <>
                  {' '}Your free pilot runs through <strong>{trialDate}</strong>.
                </>
              )}
            </p>

            <div className="mt-6 grid grid-cols-2 gap-4 text-[12px] text-[#4A5B74]">
              <Fact label="Institution" value={institutionFull} />
              <Fact label="Seats provisioned" value={`${org.max_seats}`} />
              <Fact label="Admin dashboard" value={`lecsy.app/org/${org.slug}`} />
              <Fact label="Your admin email" value={userEmail} />
              {trialDate && <Fact label="Pilot ends" value={trialDate} />}
              <Fact label="Support" value="founder@lecsy.app" />
            </div>
          </section>

          {/* TEACHER QUICKSTART */}
          <section className="mb-10">
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-2">
              Section 1 · For teachers
            </p>
            <h2 className="text-[24px] font-semibold mb-4">Starting a bilingual captioned session.</h2>

            <ol className="space-y-3 text-[14px] text-[#2B3A57] leading-relaxed list-decimal pl-5">
              <li>
                <strong className="text-[#0B1E3F]">Download Lecsy</strong> on any iPhone running iOS 17.6 or
                later (search &ldquo;lecsy&rdquo; on the App Store).
              </li>
              <li>
                <strong className="text-[#0B1E3F]">Sign in</strong> with the email your admin invited. The
                org badge for {displayName} will appear automatically.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">Open the app during class</strong> and tap the record
                button. The classroom mic picks up your voice; captions appear in the student&apos;s app in
                real time.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">After class</strong> students get an AI summary and can
                run exam prep on the transcript. You don&apos;t need to do anything.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">Audio stays on the iPhone.</strong> Lecsy streams the
                audio to Deepgram for transcription and discards it. Your voice is not stored on our
                servers.
              </li>
            </ol>
          </section>

          <div className="page-break" />

          {/* STUDENT QUICKSTART */}
          <section className="mb-10">
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-2">
              Section 2 · For students
            </p>
            <h2 className="text-[24px] font-semibold mb-4">Reading lectures in your native language.</h2>

            <ol className="space-y-3 text-[14px] text-[#2B3A57] leading-relaxed list-decimal pl-5">
              <li>
                <strong className="text-[#0B1E3F]">Install Lecsy</strong> from the App Store. Sign in with
                the school email your program used to invite you.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">Set your caption language</strong> to your native
                language (Japanese, Spanish, Chinese, etc.) in Settings → Language.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">Open the app at the start of lecture.</strong> Bilingual
                captions appear side-by-side — the teacher&apos;s English on one side, your language on the
                other, live.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">After class</strong> tap the lecture to read the full
                transcript, the AI summary, and any exam questions Lecsy generated.
              </li>
              <li>
                <strong className="text-[#0B1E3F]">Offline:</strong> the audio recorder works without
                internet. Captions need a network connection.
              </li>
            </ol>
          </section>

          {/* ADMIN QUICKSTART */}
          <section className="mb-10">
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-2">
              Section 3 · For you (program admin)
            </p>
            <h2 className="text-[24px] font-semibold mb-4">Running {displayName} from the dashboard.</h2>

            <ul className="space-y-3 text-[14px] text-[#2B3A57] leading-relaxed">
              {[
                { t: 'Invite your team', d: 'Paste emails or upload a CSV at Members → Add Members. Pending members activate automatically when they first sign in.' },
                { t: 'Watch usage', d: 'Dashboard shows this-week recordings, minutes transcribed, and active students. Usage page gives per-student breakdowns.' },
                { t: 'Export for records', d: 'Usage and Transcripts pages have CSV export — for your accreditor, ADA office, or your own semester report.' },
                { t: 'Build a program glossary', d: 'AI Assist → Glossary extracts domain terms (Biology, Economics, Nursing) from real transcripts. Reusable across cohorts.' },
                { t: 'Audit trail', d: 'Every invite, removal, and settings change is logged. Available on request.' },
              ].map((i) => (
                <li key={i.t} className="flex gap-3">
                  <span className="mt-1 w-1.5 h-1.5 rounded-full bg-[#0B1E3F] flex-shrink-0" />
                  <span>
                    <strong className="text-[#0B1E3F]">{i.t}.</strong> {i.d}
                  </span>
                </li>
              ))}
            </ul>
          </section>

          <div className="page-break" />

          {/* PRIVACY */}
          <section className="mb-10">
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-2">
              Privacy posture at a glance
            </p>
            <h2 className="text-[24px] font-semibold mb-4">What happens to student data.</h2>

            <div className="grid grid-cols-2 gap-x-6 gap-y-3 text-[13px] text-[#4A5B74]">
              {[
                ['Audio', 'Streamed to Deepgram for real-time transcription, discarded. Never persisted by Lecsy.'],
                ['Transcript text', 'Stored in Supabase Postgres, scoped to your organization via RLS.'],
                ['Encryption', 'TLS 1.2+ in transit. AES-256 at rest.'],
                ['Data residency', 'United States, AWS us-east-1.'],
                ['Retention', `${settings.retention_days ?? 90} days usage logs · text until deletion.`],
                ['Deletion SLA', '30 days on termination, 90 days backup expiration.'],
                ['FERPA', 'Aligned by design. DPA + Addendum available.'],
                ['Sub-processors', 'Deepgram · Supabase · OpenAI · Stripe.'],
              ].map(([k, v]) => (
                <div key={k}>
                  <div className="text-[10px] font-semibold uppercase tracking-wider text-[#8A9BB5]">{k}</div>
                  <div className="leading-relaxed">{v}</div>
                </div>
              ))}
            </div>

            <p className="mt-5 text-[12px] text-[#4A5B74]">
              For the full HECVAT Lite answers and DPA, email{' '}
              <a href="mailto:founder@lecsy.app" className="underline">founder@lecsy.app</a>.
            </p>
          </section>

          {/* SUPPORT + SIGN-OFF */}
          <section className="border-t-2 border-[#0B1E3F] pt-6">
            <h2 className="text-[20px] font-semibold mb-3">Questions, changes, or emergencies.</h2>
            <div className="grid grid-cols-2 gap-4 text-[13px] text-[#4A5B74] leading-relaxed">
              <div>
                <div className="text-[10px] font-semibold uppercase tracking-wider text-[#8A9BB5] mb-1">Email</div>
                <div className="font-mono text-[#0B1E3F]">founder@lecsy.app</div>
                <div className="text-[11px] mt-1">Reply within one business day.</div>
              </div>
              <div>
                <div className="text-[10px] font-semibold uppercase tracking-wider text-[#8A9BB5] mb-1">On-campus</div>
                <div className="text-[#0B1E3F]">Founder drives to you.</div>
                <div className="text-[11px] mt-1">Gainesville, FL · 48h notice.</div>
              </div>
            </div>

            <p className="mt-8 text-[11px] text-[#8A9BB5]">
              Prepared {today} · lecsy.app/org/{org.slug} · Lecsy is a founder-led product; this document
              reflects the current product and the current security posture. If anything on this page
              changes, your admin email will receive 30-day advance notice.
            </p>
          </section>
        </article>
      </div>
    </div>
  )
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] font-semibold uppercase tracking-wider text-[#8A9BB5]">{label}</div>
      <div className="font-mono text-[#0B1E3F] break-all">{value}</div>
    </div>
  )
}
