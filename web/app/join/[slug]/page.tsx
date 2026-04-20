// /join/[slug] — QR code landing page used in classroom pilots.
//
// Flow: Kim's class scans a QR pointing at lecsy.app/join/fmcc-pilot →
//   1) page resolves the org name from Supabase (public read, no auth needed)
//   2) shows "You've been invited to {Org Name}" + clear 3-step instructions
//   3) one big App Store button + "I'm already installed" sign-in link
//
// Org membership is wired up server-side: students whose emails were
// pre-registered into organization_members (status='pending') by the org
// admin are auto-activated by PostLoginCoordinator on first sign-in. So
// this page does NOT need to deep-link into the iOS app or carry org context
// — it's a plain marketing/instruction page that exists to make the
// classroom moment less confusing.

import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createAdminClient } from '@/utils/supabase/admin'
import { APP_STORE_URL } from '@/lib/constants'

export const dynamic = 'force-dynamic'

interface PageProps {
  params: { slug: string }
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

export default async function JoinPage({ params }: PageProps) {
  const org = await getOrg(params.slug)
  if (!org) notFound()

  return (
    <main className="min-h-screen bg-gradient-to-b from-blue-50 via-white to-white">
      <div className="max-w-xl mx-auto px-5 pt-16 pb-24">
        {/* Header / org card */}
        <div className="text-center mb-8">
          <span className="inline-flex items-center gap-2 px-3 py-1 mb-4 text-xs font-semibold uppercase tracking-wider text-blue-700 bg-blue-100 rounded-full">
            <span className="w-1.5 h-1.5 rounded-full bg-blue-600 animate-pulse" />
            You&apos;re invited
          </span>
          {org.logo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={org.logo_url}
              alt={`${org.name} logo`}
              className="w-20 h-20 mx-auto mb-5 rounded-2xl object-cover shadow-sm border border-gray-200"
            />
          ) : (
            <div className="w-20 h-20 mx-auto mb-5 rounded-2xl bg-blue-600 text-white flex items-center justify-center shadow-sm">
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 14l9-5-9-5-9 5 9 5z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
              </svg>
            </div>
          )}
          <h1 className="text-3xl sm:text-4xl font-bold tracking-tight text-gray-900 mb-2">
            Welcome to {org.name}
          </h1>
          <p className="text-gray-600">
            Lecsy turns your lectures into real-time captions and a study-ready transcript.
          </p>
        </div>

        {/* Step list */}
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 sm:p-8 mb-6">
          <ol className="space-y-5">
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-7 h-7 rounded-full bg-blue-600 text-white text-sm font-bold flex items-center justify-center">
                1
              </span>
              <div>
                <h2 className="font-semibold text-gray-900 mb-1">Install Lecsy from the App Store</h2>
                <p className="text-sm text-gray-600">Free download. iPhone running iOS 17.6 or newer.</p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-7 h-7 rounded-full bg-blue-600 text-white text-sm font-bold flex items-center justify-center">
                2
              </span>
              <div>
                <h2 className="font-semibold text-gray-900 mb-1">Sign in with your school email</h2>
                <p className="text-sm text-gray-600">
                  Use the same email address {org.name} has on file. Apple, Google, and Magic Link sign-in
                  all work — pick whichever is fastest.
                </p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-7 h-7 rounded-full bg-blue-600 text-white text-sm font-bold flex items-center justify-center">
                3
              </span>
              <div>
                <h2 className="font-semibold text-gray-900 mb-1">Tap the red button when class starts</h2>
                <p className="text-sm text-gray-600">
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
          className="block w-full text-center h-14 leading-[3.5rem] rounded-2xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors shadow-lg shadow-blue-600/20"
        >
          Download Lecsy for iPhone
        </a>
        <p className="mt-4 text-center text-sm text-gray-500">
          Already installed?{' '}
          <Link href="/login" className="text-blue-600 font-medium hover:underline">
            Open the web app
          </Link>
        </p>

        {/* Privacy note — required for ESL/FERPA contexts */}
        <div className="mt-10 p-5 rounded-xl bg-gray-50 border border-gray-200 text-sm text-gray-600 leading-relaxed">
          <p className="font-semibold text-gray-800 mb-1">Your privacy in {org.name}</p>
          <p>
            Audio is processed for transcription and is never stored by Lecsy. Transcript text is scoped to
            your organization with row-level security. Before your first recording you&apos;ll see a one-time
            FERPA-aligned consent prompt. See our{' '}
            <Link href="/privacy" className="text-blue-600 hover:underline">
              Privacy Policy
            </Link>{' '}
            for details.
          </p>
        </div>
      </div>
    </main>
  )
}
