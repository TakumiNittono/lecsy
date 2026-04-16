import Link from 'next/link'

interface Props {
  slug: string
  orgName: string
  displayName?: string
  trialEndsAt: string | null
  hasLogo: boolean
  memberCount: number
  maxSeats: number
}

export default function WelcomeCard({
  slug,
  orgName,
  displayName,
  trialEndsAt,
  hasLogo,
  memberCount,
  maxSeats,
}: Props) {
  const school = displayName || orgName
  const daysLeft = trialEndsAt
    ? Math.max(0, Math.ceil((new Date(trialEndsAt).getTime() - Date.now()) / (1000 * 60 * 60 * 24)))
    : null

  const steps = [
    {
      done: hasLogo,
      title: 'Add your logo',
      desc: 'Shown in the dashboard header and on the printable setup guide.',
      href: `/org/${slug}/settings`,
      cta: hasLogo ? 'Update logo' : 'Upload logo',
    },
    {
      done: memberCount >= 2,
      title: 'Invite your first admins',
      desc: 'Add coordinators and IT so you\'re not the only account with access.',
      href: `/org/${slug}/members`,
      cta: 'Invite admins',
    },
    {
      done: memberCount >= 3,
      title: 'Invite your first class',
      desc: `You have ${maxSeats - memberCount} student seats available. Paste emails or upload a CSV.`,
      href: `/org/${slug}/members`,
      cta: 'Invite students',
    },
  ]

  const completed = steps.filter((s) => s.done).length

  return (
    <div className="bg-gradient-to-br from-[#0B1E3F] to-[#16315C] rounded-2xl text-white p-6 md:p-8 mb-8 shadow-lg">
      <div className="flex flex-wrap items-start justify-between gap-4 mb-6">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#F5C96B] mb-2">
            Welcome
          </p>
          <h2 className="text-2xl md:text-3xl font-semibold leading-tight">
            Let&apos;s get {school} set up.
          </h2>
          {daysLeft !== null && daysLeft > 0 && (
            <p className="text-sm text-[#C8D1E0] mt-1">
              Free pilot: <strong className="text-[#F5C96B]">{daysLeft} days</strong> remaining
            </p>
          )}
        </div>
        <div className="text-right">
          <div className="text-xs text-[#8A9BB5] uppercase tracking-wider mb-1">Setup progress</div>
          <div className="font-semibold text-xl">
            {completed}/{steps.length} complete
          </div>
        </div>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        {steps.map((step, i) => (
          <div
            key={step.title}
            className={`rounded-xl border p-5 ${
              step.done
                ? 'border-white/10 bg-white/5'
                : 'border-[#F5C96B]/30 bg-[#F5C96B]/10'
            }`}
          >
            <div className="flex items-center gap-2 mb-2">
              <span
                className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                  step.done ? 'bg-[#F5C96B] text-[#0B1E3F]' : 'bg-white/10 text-[#F5C96B] border border-[#F5C96B]/50'
                }`}
              >
                {step.done ? '✓' : i + 1}
              </span>
              <h3 className={`font-semibold text-sm ${step.done ? 'text-white/70 line-through' : 'text-white'}`}>
                {step.title}
              </h3>
            </div>
            <p className={`text-xs leading-relaxed mb-3 ${step.done ? 'text-white/50' : 'text-[#C8D1E0]'}`}>
              {step.desc}
            </p>
            <Link
              href={step.href}
              className={`inline-flex items-center gap-1 text-xs font-semibold ${
                step.done
                  ? 'text-white/60 hover:text-white'
                  : 'text-[#F5C96B] hover:text-[#F7D688]'
              }`}
            >
              {step.cta}
              <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </Link>
          </div>
        ))}
      </div>

      <div className="mt-6 pt-5 border-t border-white/10 flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-[#8A9BB5]">
          Need help? Email{' '}
          <a href="mailto:founder@lecsy.app" className="text-[#F5C96B] underline">founder@lecsy.app</a>
          {' '}— reply within one business day.
        </p>
        <Link
          href={`/org/${slug}/onboarding/guide`}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-white/10 hover:bg-white/15 text-sm font-medium text-white transition-colors"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          Printable setup guide
        </Link>
      </div>
    </div>
  )
}
