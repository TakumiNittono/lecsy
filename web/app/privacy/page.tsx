import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description:
    'Lecsy Privacy Policy — how we handle your audio, transcripts, and personal data. Audio is processed via Deepgram (auto-deleted within 30 days) and never stored by Lecsy.',
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8 md:p-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Privacy Policy</h1>

          <p className="text-gray-600 mb-8 text-sm">
            <strong>Last Updated:</strong> April 19, 2026
          </p>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">1. Introduction</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy (&ldquo;the App&rdquo;) is built for international students who attend English-language lectures.
              This Privacy Policy explains what information we collect, how we use it, and your rights regarding your data.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">2. How Your Data Flows</h2>
            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-4">
              <p className="text-blue-800 font-semibold mb-2">The short version</p>
              <p className="text-blue-900 leading-relaxed text-sm">
                When you record a lecture, audio is streamed in real time to <strong>Deepgram</strong>
                {' '}(our speech-to-text provider) over an encrypted connection.
                Deepgram returns transcript text immediately and <strong>automatically deletes the processed audio within 30 days</strong>.
                <strong> Lecsy itself never stores your audio</strong> on its servers.
                Transcript text is saved on your device and, when you are signed in, synced to our database for cross-device access.
                When you tap AI Summary or Bilingual Translation, the transcript <strong>text</strong> (not audio) is sent to OpenAI to generate the result.
              </p>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 border border-gray-300 text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Data</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Your Device</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Lecsy Server</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Deepgram</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">OpenAI</th>
                    <th className="px-4 py-3 text-left font-semibold text-gray-700 border-b">Condition</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Audio (live stream)</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes (auto-deleted &lt; 30d)</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Streamed only while you are recording</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Audio (.m4a file)</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Never</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Local backup file, stays on your device</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Transcript text</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">No</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Synced when signed in</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">AI Summary / Translation input</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Text only, never audio; only on demand</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Account info (email, name, ID)</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-gray-700 border-b">Yes</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">No</td>
                    <td className="px-4 py-3 text-gray-600 border-b">Apple / Google / Magic Link sign-in</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-gray-700 border-b font-medium">Ads / Trackers / IDFA</td>
                    <td className="px-4 py-3 text-gray-700 border-b">&mdash;</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">None</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">None</td>
                    <td className="px-4 py-3 text-green-700 border-b font-semibold">None</td>
                    <td className="px-4 py-3 text-gray-600 border-b">No ad SDKs installed; IDFA not collected</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">3. Real-Time Transcription via Deepgram</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Lecsy uses <strong>Deepgram Nova-3</strong> to perform real-time speech-to-text on lecture audio.
              While you are recording, audio is streamed to Deepgram&apos;s servers over an encrypted (TLS) WebSocket
              connection. Transcript text is returned within milliseconds and stored on your device.
            </p>
            <p className="text-gray-700 leading-relaxed mb-4">
              <strong>Deepgram&apos;s data handling:</strong>
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4 mb-4">
              <li>Audio is processed only to produce the transcript and is <strong>not used to train Deepgram&apos;s models</strong> (per Deepgram&apos;s API terms).</li>
              <li>Processed audio is <strong>automatically deleted within 30 days</strong>.</li>
              <li>Lecsy uses short-lived API tokens (15-minute TTL) to authorize each session, so no permanent credentials live on your phone.</li>
              <li>For organization customers we will negotiate a <strong>Zero Data Retention</strong> agreement with Deepgram on request.</li>
            </ul>
            <p className="text-gray-700 leading-relaxed">
              <strong>If you are offline</strong>, real-time transcription is unavailable. The local audio file is still saved and you can re-attempt transcription when you reconnect.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">4. AI Summaries, Translation &amp; Study Guides</h2>
            <div className="bg-amber-50 border-l-4 border-amber-500 p-4 mb-4">
              <p className="text-amber-900 leading-relaxed text-sm">
                When you tap <strong>AI Summary</strong>, <strong>Bilingual Translation</strong>, or <strong>Study Guide</strong>,
                the transcript <strong>text</strong> (never audio) is sent from our server to <strong>OpenAI&apos;s API</strong>
                {' '}(GPT-4o-mini and gpt-5-nano) to generate the result. OpenAI does not use API content to train its models.
                Lecsy does not use your data to train AI models either.
              </p>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">5. Information We Collect</h2>
            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Account Information (optional but required for cloud features)</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Email address (from Apple ID or Google account)</li>
                  <li>Display name</li>
                  <li>User ID</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Audio Recordings</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Lecture audio recorded through the app</li>
                  <li><strong className="text-green-700">Local file (.m4a) stored on your device only — never uploaded to Lecsy servers</strong></li>
                  <li>Streamed to Deepgram in real time for transcription, then deleted by Deepgram within 30 days (see Section 3)</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Transcription Text</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Text returned by Deepgram during recording</li>
                  <li>Stored locally on your device</li>
                  <li>If you are signed in, text is synced to our server (Supabase) for cross-device access and backup</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Usage Data</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Recording minutes per day / per month (for usage caps and billing)</li>
                  <li>Device type and operating system version</li>
                </ul>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">6. How We Use Your Information</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Real-Time Transcription:</strong> Audio is streamed to Deepgram while recording; transcript text is returned and stored.</li>
              <li><strong>AI Features:</strong> Transcript text is sent to OpenAI when you use AI Summary, Translation, or Study Guide.</li>
              <li><strong>Authentication:</strong> To verify your identity and manage your account.</li>
              <li><strong>Data Synchronization:</strong> To sync transcript text across devices.</li>
              <li><strong>Service Operation:</strong> Anonymized usage data to enforce quotas and improve reliability.</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">7. Data Storage</h2>
            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">On Your Device</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Audio recording files (.m4a)</li>
                  <li>Transcript text and segments</li>
                  <li>App settings and preferences</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">On Lecsy Servers (Supabase, when signed in)</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Account information (email, display name)</li>
                  <li>Transcript text (for cross-device sync and backup)</li>
                  <li>Usage logs (rate-limit and billing tracking)</li>
                  <li><strong className="text-green-700">Audio recordings are never stored by Lecsy</strong></li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Security Measures</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>All data is transferred over encrypted connections (HTTPS/TLS 1.3)</li>
                  <li>Data at rest is encrypted</li>
                  <li>Row-level security ensures you can only access your own data</li>
                  <li>Short-lived (15-minute TTL) API tokens for Deepgram, never long-lived secrets in the app</li>
                </ul>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">8. Sub-Processors</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We use the following third-party services (sub-processors) to operate Lecsy. Each is bound by their own privacy and security commitments:
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
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Deepgram</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Real-time speech-to-text (Nova-3)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Live audio stream (auto-deleted &lt; 30 days)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://deepgram.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        deepgram.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>OpenAI</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">AI summaries, translation, study guides</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcript text only (no audio); on demand</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://openai.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        openai.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Supabase</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Database, authentication, cloud sync</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Account info, transcript text (no audio)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://supabase.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        supabase.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Stripe</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Subscription billing</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Email, payment method (held by Stripe)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://stripe.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        stripe.com/privacy
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
              <li><strong>Sub-Processors:</strong> Listed in Section 8, solely to operate the Service</li>
              <li><strong>Legal Requirements:</strong> To comply with applicable laws or legal processes</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4 font-semibold">
              We never share or sell your transcript text or audio data for advertising or model training.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">10. AI Training</h2>
            <p className="text-gray-700 leading-relaxed">
              We do <strong>not</strong> use your audio, transcripts, or any other personal data to train artificial intelligence models.
              Our sub-processors (Deepgram, OpenAI) also commit, in their API terms, to not using your data for model training.
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
              <li>Cloud transcript data is retained while your account is active</li>
              <li>Upon account deletion, all cloud data is deleted within 30 days</li>
              <li>Audio sent to Deepgram for live transcription is auto-deleted within 30 days by Deepgram</li>
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
              Lecsy is operated from the United States. Audio (briefly) and transcript text may be processed in the
              United States by Deepgram, OpenAI, and Supabase. By using the Service, you consent to such transfers.
              Where required by law, we rely on Standard Contractual Clauses (SCCs) for cross-border transfers.
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
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">17. For Schools &amp; Organizations</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              When Lecsy is provided to a school, university, language program, or other educational
              institution under a written pilot or license agreement, the following commitments apply in
              addition to the rest of this policy:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4 mb-4">
              <li>
                <strong>FERPA &ldquo;school official&rdquo;:</strong> Lecsy operates as a school official with a
                legitimate educational interest, processing student data only as directed by the institution.
                We do not disclose personally identifiable information from education records to third
                parties except as permitted by FERPA or with consent.
              </li>
              <li>
                <strong>Lecsy never stores audio:</strong> Audio is streamed only during recording for
                real-time transcription. The local .m4a file remains on the student&apos;s device.
              </li>
              <li>
                <strong>Deepgram retention &amp; Zero Data Retention (ZDR):</strong> By default, Deepgram
                automatically deletes processed audio within 30 days. For institutional deployments we will
                negotiate a Zero Data Retention agreement with Deepgram on request, so audio is discarded
                after transcription with no retention window.
              </li>
              <li>
                <strong>Transcript storage:</strong> Transcript text is stored in encrypted Supabase
                Postgres with row-level security scoped so that only members of the institution&apos;s
                organization can access its data. Audio is never persisted on Lecsy infrastructure.
              </li>
              <li>
                <strong>Student consent:</strong> Before a student records under an organization, the iOS
                client surfaces a FERPA-aligned consent prompt. The acknowledgement timestamp is written to
                the student&apos;s organization membership record so administrators can produce evidence of
                consent. Consent can be withdrawn by emailing the school&apos;s Lecsy administrator or
                <a href="mailto:privacy@lecsy.app" className="text-blue-600 hover:underline"> privacy@lecsy.app</a>.
              </li>
              <li>
                <strong>No model training on student data:</strong> Neither Lecsy nor our sub-processors
                (Deepgram, OpenAI) use institutional audio or transcripts to train AI models, per their API
                terms.
              </li>
              <li>
                <strong>Compliance documentation on request:</strong> We provide a Data Processing Addendum
                (DPA) with Standard Contractual Clauses for cross-border transfers, and HECVAT-Lite
                responses for institutional security reviews.
              </li>
            </ul>
            <p className="text-gray-700 leading-relaxed">
              Institutional inquiries:{' '}
              <a href="mailto:support@lecsy.app" className="text-blue-600 hover:underline">
                support@lecsy.app
              </a>
              .
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">18. Changes to This Policy</h2>
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
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">19. Contact Us</h2>
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
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Audio (live)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Real-time transcription</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Streamed to Deepgram, deleted &lt; 30 days</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Deepgram only</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Audio (.m4a)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Local backup of recording</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Your device only</td>
                    <td className="px-4 py-3 text-sm font-semibold text-green-700 border-b">No one</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcript text</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Display, search, cross-device backup</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Device + cloud (if signed in)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Supabase (our cloud provider)</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">AI summary / translation input</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Generate summaries, translations, study guides</td>
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
                <li className="text-green-700">&#10003; Audio is never stored on Lecsy servers</li>
                <li className="text-green-700">&#10003; Live audio sent to Deepgram is auto-deleted within 30 days</li>
                <li className="text-green-700">&#10003; AI features send transcript text only (not audio), only on demand</li>
                <li className="text-green-700">&#10003; No data is sold to third parties</li>
                <li className="text-green-700">&#10003; No data is used to train AI models</li>
                <li className="text-green-700">&#10003; You can delete your data anytime</li>
              </ul>
            </div>
          </section>

          <div className="border-t pt-8 mt-8">
            <p className="text-gray-600 text-sm mb-4 italic">
              This Privacy Policy is effective as of April 19, 2026.
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
