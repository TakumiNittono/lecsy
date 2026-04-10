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
            Last updated: April 9, 2026
          </p>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">1. Overview</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy (&ldquo;the Service&rdquo;) is a lecture recording and AI study application that provides on-device transcription,
              AI-powered summaries, exam preparation features, and cross-device transcript sync.
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
            <h2 className="text-xl font-semibold text-gray-800 mb-4">3. Pricing</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              All features are free through June 1, 2026. No ads, no subscription, no credit card required.
            </p>
            <p className="text-gray-700 leading-relaxed">
              After June 1, 2026, pricing will be determined based on user feedback. Our commitment: features that
              are free today will remain free for existing users. We will not retroactively paywall features you
              already rely on.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">4. How Your Data Is Processed</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              By using the Service, you acknowledge the following data processing:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Audio:</strong> Recorded and transcribed entirely on your device. Never uploaded.</li>
              <li><strong>Transcript text:</strong> Synced to our server (Supabase) when signed in, for backup and web access. You can disable this.</li>
              <li><strong>AI Summary &amp; Exam Mode:</strong> When you tap the button, transcript text (not audio) is sent to OpenAI&apos;s GPT-4o-mini API. OpenAI does not train on API content.</li>
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
