import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Lecsy Privacy Policy — how we handle your audio, transcripts, and personal data. Audio never leaves your device.',
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8 md:p-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Privacy Policy</h1>

          <p className="text-gray-600 mb-8 text-sm">
            <strong>Last Updated:</strong> April 9, 2026
          </p>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">1. Introduction</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy (&ldquo;the App&rdquo;) respects your privacy and is committed to protecting your personal information.
              This Privacy Policy explains what information we collect, how we use it, and your rights regarding your data.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">2. How Your Data Flows</h2>
            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-4">
              <p className="text-blue-800 font-semibold mb-2">The short version</p>
              <p className="text-blue-900 leading-relaxed text-sm">
                Recording and transcription happen <strong>entirely on your iPhone</strong> via WhisperKit (on-device AI).
                Your audio file (.m4a) is <strong>never uploaded anywhere</strong>.
                Transcript text syncs to our server only when you&apos;re signed in (you can turn this off).
                When you tap AI Summary or Exam Mode, the transcript <strong>text</strong> (not audio) is sent to OpenAI to generate the result.
              </p>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 border border-gray-300 text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Data</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">On Device</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Our Server</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">OpenAI</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Condition</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Audio (.m4a)</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Always stays on device only</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Transcript text</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">No</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Synced when signed in; disable in Settings &rarr; Privacy &rarr; Cloud Sync</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">AI Summary / Exam Mode input</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Only when you tap the button; text only, never audio</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Account info (email, name, ID)</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">No</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Via Apple / Google / Magic Link sign-in</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Ads / Trackers / IDFA</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">None</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">None</td>
                    <td className="px-4 py-3 text-gray-600 border-b">No ad SDKs installed; IDFA not collected</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">3. On-Device Transcription</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Lecsy performs all speech-to-text transcription <strong>entirely on your device</strong> using
              the open-source WhisperKit library (Apple CoreML). No audio data is sent to any server for transcription.
            </p>
            <p className="text-gray-700 leading-relaxed mb-4">
              The AI model (~150 MB) is downloaded once from HuggingFace on first launch. During this download,
              no user data is transmitted — only model weights are downloaded. After that, transcription works completely offline.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">4. AI Summaries &amp; Exam Mode</h2>
            <div className="bg-amber-50 border-l-4 border-amber-500 p-4 mb-4">
              <p className="text-amber-900 leading-relaxed text-sm">
                When you tap the <strong>AI Summary</strong> or <strong>Exam Mode</strong> button, the transcript
                <strong> text</strong> (never audio) is sent from our server to <strong>OpenAI&apos;s GPT-4o-mini</strong> API
                to generate the summary or exam questions. OpenAI does not use API content to train its models.
                We do not use your data to train AI models either.
              </p>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">5. Information We Collect</h2>

            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Account Information (optional)</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Email address (from Apple ID or Google account)</li>
                  <li>Display name</li>
                  <li>User ID</li>
                </ul>
                <p className="text-gray-600 text-sm mt-1 ml-4">
                  Collected only when you choose to sign in. The app can be used without an account for recording and transcription.
                </p>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Audio Recordings</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Lecture audio recorded through the app</li>
                  <li><strong className="text-green-700">Stored on your device only — never uploaded to any server</strong></li>
                  <li><strong className="text-green-700">Processed on-device only — never sent to any third-party service</strong></li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Transcription Text</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Text generated from on-device speech recognition</li>
                  <li>Stored locally on your device</li>
                  <li>If you sign in, text is synced to our server (Supabase) for cross-device access and backup</li>
                  <li>Cloud sync can be disabled: Settings &rarr; Privacy &rarr; Cloud Sync</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Usage Data</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Feature usage statistics (for rate limiting)</li>
                  <li>Device type and operating system version</li>
                </ul>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">6. How We Use Your Information</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>On-Device Transcription:</strong> Audio is processed locally using WhisperKit (Apple CoreML). No data leaves your device during this process.</li>
              <li><strong>AI Features:</strong> Transcript text is sent to OpenAI GPT-4o-mini when you use AI Summary or Exam Mode.</li>
              <li><strong>Authentication:</strong> To verify your identity and manage your account (if you sign in)</li>
              <li><strong>Data Synchronization:</strong> To sync your transcription text across devices (only when signed in)</li>
              <li><strong>Service Improvement:</strong> Anonymized usage data to improve our services</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">7. Data Storage</h2>

            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">On Your Device</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Audio recording files (.m4a)</li>
                  <li>AI model files (Apple CoreML format)</li>
                  <li>Transcription text</li>
                  <li>App settings and preferences</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">In the Cloud (only when signed in)</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Account information (email, display name)</li>
                  <li>Transcription text (for cross-device sync and backup)</li>
                  <li>Usage logs (rate-limit tracking)</li>
                  <li><strong className="text-green-700">Audio recordings are never uploaded to the cloud</strong></li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Security Measures</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>All data is transferred over encrypted connections (HTTPS/TLS)</li>
                  <li>Data at rest is encrypted</li>
                  <li>Row-level security ensures you can only access your own data</li>
                  <li>On-device data is protected by iOS device security</li>
                </ul>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">8. Third-Party Services</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We use the following third-party services:
            </p>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 border border-gray-300">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Service</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Purpose</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Data Shared</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Privacy Policy</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Supabase</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Database, authentication, cloud sync</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Account info, transcription text (no audio)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://supabase.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        supabase.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>OpenAI</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">AI summaries &amp; Exam Mode (GPT-4o-mini)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcript text only (no audio); only when user taps the button</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://openai.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        openai.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Apple Sign In</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">User authentication</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Apple ID credentials</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://www.apple.com/privacy/" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        apple.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Google Sign In</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">User authentication</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Google account credentials</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        policies.google.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>HuggingFace</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">AI model hosting (one-time download)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">No user data (only model files are downloaded)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://huggingface.co/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        huggingface.co/privacy
                      </a>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">9. Data Sharing</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We do <strong>not</strong> sell, rent, or share your personal information with third parties, except in the following circumstances:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>With Your Consent:</strong> When you explicitly authorize sharing</li>
              <li><strong>Service Providers:</strong> Third-party services listed above, solely for providing our services</li>
              <li><strong>Legal Requirements:</strong> To comply with applicable laws, regulations, or legal processes</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4 font-semibold">
              Your audio recordings are never shared with anyone. They exist only on your device.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">10. AI Training</h2>
            <p className="text-gray-700 leading-relaxed">
              We do <strong>not</strong> use your audio, transcripts, or any other personal data to train artificial intelligence models.
              OpenAI does not use API content to train its models (per OpenAI&apos;s API terms). Your data is yours.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">11. Your Rights</h2>
            <div className="space-y-3">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Right to Access</h3>
                <p className="text-gray-700">You can request access to the personal data we hold about you.</p>
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Right to Rectification</h3>
                <p className="text-gray-700">You can request correction of inaccurate data.</p>
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Right to Deletion</h3>
                <p className="text-gray-700">
                  You can delete your account and all associated data directly from the app:
                  Settings &rarr; Delete Account. All data is permanently deleted immediately.
                </p>
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Right to Data Portability</h3>
                <p className="text-gray-700">You can request a copy of your data in a portable format.</p>
              </div>
            </div>
            <p className="text-gray-700 leading-relaxed mt-4">
              <strong>How to Exercise Your Rights:</strong> Contact us at{' '}
              <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                support@lecsy.app
              </a>
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">12. Data Retention</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>On-device data (audio, transcripts) remains until you delete it</li>
              <li>Cloud data is retained while your account is active</li>
              <li>Upon account deletion, all cloud data is deleted within 30 days</li>
              <li>Some data may be retained longer if required by law</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">13. Children&apos;s Privacy</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy is not intended for children under the age of 13. We do not knowingly collect personal
              information from children under 13. If you believe we have collected information from a child under 13,
              please contact us immediately.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">14. International Data Transfers</h2>
            <p className="text-gray-700 leading-relaxed">
              If you sign in, your transcription text may be transferred to and processed in countries other
              than your country of residence via our cloud provider (Supabase). By using the sync feature,
              you consent to such transfers. Audio recordings are never transferred internationally as they
              remain on your device.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">15. California Privacy Rights (CCPA)</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you are a California resident, you have additional rights under the CCPA:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Right to know what personal information is collected</li>
              <li>Right to know whether personal information is sold or disclosed</li>
              <li>Right to opt out of the sale of personal information</li>
              <li>Right to non-discrimination for exercising your rights</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4 font-semibold">
              We do not sell personal information.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">16. European Privacy Rights (GDPR)</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you are in the European Economic Area (EEA), you have rights under the GDPR including access,
              rectification, erasure, restriction of processing, data portability, and the right to object.
            </p>
            <p className="text-gray-700 leading-relaxed">
              <strong>Legal Basis for Processing:</strong> Consent, performance of a contract, and legitimate interests.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">17. Changes to This Policy</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We may update this Privacy Policy from time to time. We will notify you of significant changes through:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>In-app notifications</li>
              <li>Email (if you have provided one)</li>
              <li>Updating the &ldquo;Last Updated&rdquo; date above</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">18. Contact Us</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you have any questions about this Privacy Policy, please contact us:
            </p>
            <p className="text-gray-700">
              <strong>Email:</strong>{' '}
              <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                support@lecsy.app
              </a>
            </p>
          </section>

          <section className="mb-10 bg-gray-50 p-6 rounded-lg">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">Summary</h2>
            <div className="overflow-x-auto mb-4">
              <table className="min-w-full divide-y divide-gray-200 border border-gray-300">
                <thead className="bg-gray-100">
                  <tr>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Data</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">How It&apos;s Used</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Where It&apos;s Stored</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Shared With</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Audio recordings</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">On-device transcription (WhisperKit)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Your device only</td>
                    <td className="px-4 py-3 text-sm font-semibold text-green-700 border-b">No one</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcription text</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Display, search, cross-device backup</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Device + cloud (if signed in)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Supabase (our cloud provider)</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">AI summary / exam input</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Generate summaries &amp; exam questions</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Processed, not stored by OpenAI</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">OpenAI (text only, on demand)</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Account info</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Authentication</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Cloud (Supabase)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Supabase, Apple/Google (auth)</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="mt-4">
              <p className="text-gray-800 font-semibold mb-2">Key Points:</p>
              <ul className="list-none space-y-1">
                <li className="text-green-700">&#10003; Audio never leaves your device</li>
                <li className="text-green-700">&#10003; Transcription is on-device (WhisperKit / Apple CoreML)</li>
                <li className="text-green-700">&#10003; AI features send text only to OpenAI (not audio), only on demand</li>
                <li className="text-green-700">&#10003; Cloud sync is optional and only for transcript text</li>
                <li className="text-green-700">&#10003; No data is sold to third parties</li>
                <li className="text-green-700">&#10003; No data is used to train AI models</li>
                <li className="text-green-700">&#10003; You can delete your data anytime</li>
              </ul>
            </div>
          </section>

          <div className="border-t pt-8 mt-8">
            <p className="text-gray-600 text-sm mb-4 italic">
              This Privacy Policy is effective as of April 9, 2026.
            </p>
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
