// /join/[slug] — QR code landing page used in classroom pilots.
//
// Two flows:
//   (a) Plain /join/fmcc-pilot  — install + sign-in instructions
//   (b) /join/fmcc-pilot?code=FDDAD9  — specific invite code from a printed
//       card. Shows the code + a `lecsy://invite?code=...` deep link button
//       so one tap on a phone with Lecsy installed jumps straight into the
//       redeem flow inside the app (see lecsyApp.swift handleIncomingURL).
//
// The deep-link button on its own works even without Apple's Universal Link
// (AASA) plumbing because `lecsy://` is registered as a custom URL scheme
// in Info.plist — any QR scanner that opens links will trigger the "Open in
// Lecsy?" iOS prompt. If Lecsy isn't installed the deep link silently
// fails, which is why we also surface the App Store link right below.

import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createAdminClient } from '@/utils/supabase/admin'
import { APP_STORE_URL } from '@/lib/constants'

export const dynamic = 'force-dynamic'

interface PageProps {
  params: { slug: string }
  searchParams: { code?: string }
}

async function getOrg(slug: string) {
  const supabase = createAdminClient()
  const { data } = await supabase
    .from('organizations')
    .select('name, slug, logo_url')
    .eq('slug', slug)
    .maybeSingle()
  return data
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const org = await getOrg(params.slug)
  const orgName = org?.name || 'your school'
  return {
    title: `Join ${orgName} on Lecsy`,
    description: `You've been invited to use Lecsy in ${orgName}. Install the iOS app and sign in with your school email.`,
    robots: { index: false, follow: false },
  }
}

export default async function JoinPage({ params, searchParams }: PageProps) {
  const org = await getOrg(params.slug)
  if (!org) notFound()

  const rawCode = (searchParams.code || '').trim().replace(/\D/g, '')
  const code = /^[0-9]{6}$/.test(rawCode) ? rawCode : null
  const deepLink = code ? `lecsy://invite?code=${encodeURIComponent(code)}` : null

  return (
    <main className="min-h-screen bg-white">
      <div className="max-w-xl mx-auto px-5 pt-16 pb-24">
        {/* Header / org card */}
        <div className="text-center mb-10">
          <span className="inline-flex items-center px-3 py-1 mb-5 text-[11px] font-medium uppercase tracking-[0.18em] text-gray-600 bg-gray-100 rounded-full">
            You&apos;re invited
          </span>
          {org.logo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={org.logo_url}
              alt={`${org.name} logo`}
              className="w-20 h-20 mx-auto mb-6 rounded-2xl object-cover border border-gray-200"
            />
          ) : (
            <div className="w-20 h-20 mx-auto mb-6 rounded-2xl bg-gray-900 text-white flex items-center justify-center">
              <svg className="w-9 h-9" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 14l9-5-9-5-9 5 9 5z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
              </svg>
            </div>
          )}
          <h1 className="text-3xl sm:text-4xl font-semibold tracking-tight text-gray-900 mb-3">
            Welcome to {org.name}
          </h1>
          <p className="text-gray-500 text-[15px] leading-relaxed">
            Lecsy turns your lectures into real-time captions and a study-ready transcript.
          </p>
        </div>

        {/* Code-specific card (only when ?code=XXX is in the URL) */}
        {code && deepLink && (
          <div className="bg-white rounded-3xl border border-gray-200 shadow-sm p-7 sm:p-8 mb-6 text-center">
            <p className="text-[11px] font-medium text-gray-500 uppercase tracking-[0.18em] mb-3">
              Your invite code
            </p>
            <p
              className="text-4xl font-semibold tracking-[0.4em] font-mono text-gray-900 mb-6 select-all"
              aria-label={`Invite code ${code.split('').join(' ')}`}
            >
              {code}
            </p>
            <a
              href={deepLink}
              className="block w-full text-center h-12 leading-[3rem] rounded-full bg-gray-900 text-white text-[15px] font-medium hover:bg-gray-800 active:bg-black transition-colors"
            >
              Open in Lecsy (iOS)
            </a>
            <Link
              href={`/android?code=${encodeURIComponent(code)}`}
              className="mt-3 block w-full text-center h-12 leading-[3rem] rounded-full bg-white text-gray-900 text-[15px] font-medium border border-gray-300 hover:bg-gray-50 transition-colors"
            >
              Open on Android
            </Link>
            <p className="mt-4 text-[12px] text-gray-500 leading-relaxed">
              Tap iOS if Lecsy is already installed. Android opens the web app.
            </p>
          </div>
        )}

        {/* Step list */}
        <div className="bg-white rounded-3xl border border-gray-200 p-7 sm:p-8 mb-6">
          <ol className="space-y-6">
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-7 h-7 rounded-full bg-gray-900 text-white text-[13px] font-medium flex items-center justify-center">
                1
              </span>
              <div>
                <h2 className="font-semibold text-gray-900 mb-1 text-[15px]">Install Lecsy from the App Store</h2>
                <p className="text-[13.5px] text-gray-500 leading-relaxed">Free download. iPhone on iOS 17.6 or newer.</p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-7 h-7 rounded-full bg-gray-900 text-white text-[13px] font-medium flex items-center justify-center">
                2
              </span>
              <div>
                <h2 className="font-semibold text-gray-900 mb-1 text-[15px]">
                  {code ? 'Tap "Open in Lecsy" above' : 'Tap "Have an invite code?"'}
                </h2>
                <p className="text-[13.5px] text-gray-500 leading-relaxed">
                  {code
                    ? 'Lecsy takes the code automatically and signs you in.'
                    : `Type the 6-digit code on your card. You'll be signed in to ${org.name} instantly.`}
                </p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-7 h-7 rounded-full bg-gray-900 text-white text-[13px] font-medium flex items-center justify-center">
                3
              </span>
              <div>
                <h2 className="font-semibold text-gray-900 mb-1 text-[15px]">Tap the red button when class starts</h2>
                <p className="text-[13.5px] text-gray-500 leading-relaxed">
                  Allow microphone access, then watch live captions appear as your professor speaks.
                </p>
              </div>
            </li>
          </ol>
        </div>

        {/* CTA */}
        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="block w-full text-center h-12 leading-[3rem] rounded-full bg-gray-900 text-white text-[15px] font-medium hover:bg-gray-800 active:bg-black transition-colors"
        >
          Download Lecsy for iPhone
        </a>
        <p className="mt-4 text-center text-[13px] text-gray-500">
          Already installed?{' '}
          {code && deepLink ? (
            <a href={deepLink} className="text-gray-900 font-medium hover:underline underline-offset-2">
              Open with code {code}
            </a>
          ) : (
            <Link href="/login" className="text-gray-900 font-medium hover:underline underline-offset-2">
              Open the web app
            </Link>
          )}
        </p>

        {/* Privacy note — required for ESL/FERPA contexts */}
        <div className="mt-10 p-5 rounded-2xl bg-gray-50 border border-gray-200 text-[13.5px] text-gray-600 leading-relaxed">
          <p className="font-semibold text-gray-900 mb-1">Your privacy in {org.name}</p>
          <p>
            Audio is processed for transcription and is never stored by Lecsy. Transcript text is scoped to
            your organization with row-level security. Before your first recording you&apos;ll see a one-time
            FERPA-aligned consent prompt. See our{' '}
            <Link href="/privacy" className="text-gray-900 hover:underline underline-offset-2">
              Privacy Policy
            </Link>{' '}
            for details.
          </p>
        </div>
      </div>
    </main>
  )
}
