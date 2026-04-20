import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Support',
  description:
    'Lecsy Support — contact us, account deletion instructions, troubleshooting, and FAQ. For iOS app support, school pilots, and general questions.',
  alternates: { canonical: 'https://www.lecsy.app/support' },
};

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8 md:p-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Support</h1>
          <p className="text-gray-600 mb-10">
            Questions, bugs, or account requests? We read every message.
          </p>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">Contact</h2>
            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
              <p className="text-blue-900 text-sm mb-2">
                <strong>Email:</strong>{' '}
                <a
                  href="mailto:support@lecsy.app"
                  className="font-semibold text-blue-700 hover:underline"
                >
                  support@lecsy.app
                </a>
              </p>
              <p className="text-blue-900 text-sm">
                Typical response time: within 2 business days. For security-related issues,
                include &ldquo;[SECURITY]&rdquo; in the subject line.
              </p>
            </div>
          </section>

          <section className="mb-10" id="delete-account">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">
              Delete your account &amp; data
            </h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              You can permanently delete your Lecsy account and all associated cloud data
              directly from the iOS app:
            </p>
            <ol className="list-decimal list-inside text-gray-700 space-y-2 ml-4 mb-4">
              <li>Open the Lecsy app on your iPhone.</li>
              <li>
                Tap the <strong>Settings</strong> tab (gear icon in the top right).
              </li>
              <li>
                Scroll to the <strong>Account</strong> section.
              </li>
              <li>
                Tap <strong>Delete Account</strong> and confirm.
              </li>
            </ol>
            <p className="text-gray-700 leading-relaxed mb-4">
              Upon confirmation, your account, all synced transcripts, summaries, and usage
              history are permanently removed from our servers within 30 days. Audio files
              stored locally on your device are not affected &mdash; delete them from the app
              Library if desired.
            </p>
            <p className="text-gray-700 leading-relaxed">
              If you cannot access the app, email{' '}
              <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                support@lecsy.app
              </a>{' '}
              from the address registered to your account and we will process the deletion
              manually within 5 business days.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">
              Frequently asked questions
            </h2>

            <div className="space-y-6">
              <div>
                <h3 className="font-semibold text-gray-900 mb-2">
                  The app crashes when I start recording.
                </h3>
                <p className="text-gray-700 text-sm leading-relaxed">
                  Make sure microphone permission is enabled: iOS Settings &rarr; Lecsy &rarr;
                  Microphone. If it still crashes, restart the app and email us the device
                  model and iOS version.
                </p>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-2">
                  Live captions aren&apos;t showing during recording.
                </h3>
                <p className="text-gray-700 text-sm leading-relaxed">
                  Live captions require an active internet connection and a paid plan (or an
                  organization invitation). Free users can still record and transcribe after
                  the recording ends using the on-device engine.
                </p>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-2">
                  I forgot which email I signed up with.
                </h3>
                <p className="text-gray-700 text-sm leading-relaxed">
                  Email{' '}
                  <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                    support@lecsy.app
                  </a>{' '}
                  with your name and approximate sign-up date. We will help you locate the
                  account.
                </p>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-2">
                  How do I export my transcripts?
                </h3>
                <p className="text-gray-700 text-sm leading-relaxed">
                  Open a lecture in the app Library and tap the share icon to export as
                  plain text. Web export is available at{' '}
                  <a href="/app" className="text-blue-600 hover:underline">
                    lecsy.app/app
                  </a>{' '}
                  once you sign in.
                </p>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-2">
                  Is recording lectures legal at my school?
                </h3>
                <p className="text-gray-700 text-sm leading-relaxed">
                  Most U.S. universities permit personal-study recording, sometimes with
                  instructor notice. See our{' '}
                  <Link
                    href="/how-to-record-lectures-legally"
                    className="text-blue-600 hover:underline"
                  >
                    guide on recording lectures legally
                  </Link>{' '}
                  and always check your school&apos;s policy.
                </p>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-2">
                  I&apos;m a faculty member / administrator. How do I run a pilot?
                </h3>
                <p className="text-gray-700 text-sm leading-relaxed">
                  Visit our{' '}
                  <Link href="/schools" className="text-blue-600 hover:underline">
                    schools page
                  </Link>{' '}
                  or email{' '}
                  <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                    support@lecsy.app
                  </a>{' '}
                  with the subject &ldquo;Pilot request&rdquo;.
                </p>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">
              Security &amp; privacy reports
            </h2>
            <p className="text-gray-700 leading-relaxed">
              Responsible disclosure of a security issue?{' '}
              <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                support@lecsy.app
              </a>{' '}
              with &ldquo;[SECURITY]&rdquo; in the subject. We acknowledge within 3 business
              days and will coordinate disclosure timing with you.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">Legal</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
              <li>
                <Link href="/privacy" className="text-blue-600 hover:underline">
                  Privacy Policy
                </Link>
              </li>
              <li>
                <Link href="/terms" className="text-blue-600 hover:underline">
                  Terms of Service
                </Link>
              </li>
            </ul>
          </section>

          <div className="border-t pt-8 mt-8">
            <Link
              href="/"
              className="text-blue-600 hover:text-blue-800 font-medium inline-flex items-center"
            >
              <span>&larr;</span>
              <span className="ml-2">Back to home</span>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
