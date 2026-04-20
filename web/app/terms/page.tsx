import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: 'Lecsy Terms of Service — rules for using the lecture recording and AI transcription app.',
};

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-8">Terms of Service</h1>

          <p className="text-gray-600 mb-6">
            Last updated: April 19, 2026
          </p>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">1. Overview</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy (&ldquo;the Service&rdquo;) is a lecture recording and AI study application built for international students.
              It provides real-time bilingual captions powered by Deepgram, AI-powered summaries and study guides
              powered by OpenAI, and cross-device transcript sync via Supabase.
              By using the Service, you agree to these Terms. If you do not agree, do not use the Service.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">2. Accounts</h2>
            <p className="text-gray-700 leading-relaxed">
              Recording and transcription work without an account. To use cloud sync, AI summaries, Exam Mode,
              and web access, you must sign in with Apple ID, Google, or Magic Link.
              You are responsible for safeguarding your account credentials and for all activity under your account.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">3. Pricing &amp; Subscriptions</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Lecsy is currently free to download and use via the App Store. The core Free tier &mdash;
              lecture recording, on-device transcription, and basic AI Study Guide &mdash; requires no payment
              and no subscription.
            </p>
            <p className="text-gray-700 leading-relaxed mb-4">
              Additional tiers are offered under two distinct paths:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4 mb-4">
              <li>
                <strong>Organization plans</strong> (schools, universities, language institutes): provided
                under a separate written agreement between Lecsy and the institution. Pricing is negotiated
                per pilot or license and invoiced directly to the organization. See{' '}
                <Link href="/schools" className="text-blue-600 hover:underline">
                  lecsy.app/schools
                </Link>
                .
              </li>
              <li>
                <strong>Individual paid tiers</strong> (Student / Pro / Power): currently in development. No
                in-app purchase path is available at this time. Indicative pricing is shown on{' '}
                <Link href="/pricing" className="text-blue-600 hover:underline">
                  lecsy.app/pricing
                </Link>{' '}
                for planning purposes only and is subject to change before release.
              </li>
            </ul>
            <p className="text-gray-700 leading-relaxed">
              When individual paid tiers launch, subscription billing will be handled by Stripe and will
              always be optional &mdash; the Free tier will remain available. Subscribers will be able to
              cancel at any time from Settings &rarr; Manage Subscription; cancellation takes effect at the
              end of the current billing period and we do not issue prorated refunds.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">4. How Your Data Is Processed</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              By using the Service, you acknowledge the following data processing:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Live audio:</strong> Streamed to Deepgram (Nova-3) over an encrypted WebSocket for real-time transcription. Deepgram automatically deletes processed audio within 30 days. <strong>Lecsy never stores your audio</strong>.</li>
              <li><strong>Local audio file (.m4a):</strong> Stays on your device only.</li>
              <li><strong>Transcript text:</strong> Synced to our server (Supabase) when signed in, for backup and web access.</li>
              <li><strong>AI Summary, Translation &amp; Study Guide:</strong> When you tap the relevant button, transcript text (not audio) is sent to OpenAI&apos;s API. OpenAI does not train on API content.</li>
              <li><strong>Billing:</strong> Subscription payments are processed by Stripe. Lecsy never sees your card number.</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              For full details, see our <Link href="/privacy" className="text-blue-600 hover:underline">Privacy Policy</Link>.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">5. Acceptable Use</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              You agree not to:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Record or store content that infringes on the rights of others</li>
              <li>Use the Service for any illegal purpose</li>
              <li>Attempt to reverse-engineer, decompile, or hack the Service</li>
              <li>Circumvent security measures or rate limits</li>
              <li>Use the Service for unauthorized commercial purposes</li>
              <li>Record individuals without their consent where required by law</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">6. Intellectual Property</h2>
            <p className="text-gray-700 leading-relaxed">
              The Service and all related content (software, design, text, graphics) are owned by us.
              Content you create (recordings, transcripts, notes) belongs to you. By using the Service,
              you grant us a limited license to process your content solely to provide the Service.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">7. Disclaimer</h2>
            <p className="text-gray-700 leading-relaxed">
              The Service is provided &ldquo;as is&rdquo; without warranties of any kind, express or implied.
              Transcription accuracy is not guaranteed — always verify important content against the original audio.
              AI-generated summaries and exam questions are for study assistance only and may contain errors.
              We are not liable for damages arising from use of the Service.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">8. Account Deletion</h2>
            <p className="text-gray-700 leading-relaxed">
              You may delete your account at any time from Settings &rarr; Delete Account in the app.
              Upon deletion, all cloud data (account information, transcripts) is permanently removed within 30 days.
              On-device data (audio files, local transcripts) remains on your device until you manually delete it.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">9. Changes &amp; Termination</h2>
            <p className="text-gray-700 leading-relaxed">
              We reserve the right to modify or discontinue the Service at any time. For significant changes,
              we will provide reasonable notice. If the Service is discontinued, we will give users adequate time
              to export their data.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">9b. Organizations &amp; Educational Institutions</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              When the Service is provided to a school, university, or other organization under a separate written
              agreement, that agreement governs in case of conflict with these Terms. For institutional customers
              we will, on request:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Sign a Data Processing Addendum (DPA) with Standard Contractual Clauses for cross-border transfers</li>
              <li>Provide HECVAT-Lite responses for security review</li>
              <li>Operate as a FERPA &ldquo;school official&rdquo; with &ldquo;legitimate educational interest&rdquo;</li>
              <li>Negotiate Zero Data Retention with Deepgram for sensitive deployments</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              Contact <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">support@lecsy.app</a> for institutional inquiries.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">10. Governing Law</h2>
            <p className="text-gray-700 leading-relaxed">
              These Terms are governed by the laws of the State of California, United States.
              Any disputes shall be resolved in the courts of California.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">11. Contact</h2>
            <p className="text-gray-700 leading-relaxed">
              Questions about these Terms? Contact us:
            </p>
            <p className="text-gray-700 mt-4">
              <strong>Email:</strong>{' '}
              <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                support@lecsy.app
              </a>
            </p>
          </section>

          <div className="border-t pt-8 mt-8">
            <Link href="/" className="text-blue-600 hover:text-blue-800 font-medium inline-flex items-center">
              <span>&larr;</span>
              <span className="ml-2">Back to Home</span>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
