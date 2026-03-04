'use client';

import Link from 'next/link';

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8 md:p-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Privacy Policy</h1>

          <p className="text-gray-600 mb-8 text-sm">
            <strong>Last Updated:</strong> March 3, 2026
          </p>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">1. Introduction</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy (&ldquo;the App&rdquo;) respects your privacy and is committed to protecting your personal information.
              This Privacy Policy explains what information we collect, how we use it, and your rights regarding your data.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">2. On-Device AI Transcription</h2>
            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-4">
              <p className="text-blue-800 font-semibold mb-2">Important: No Third-Party AI Service Is Used</p>
              <p className="text-blue-900 leading-relaxed">
                Lecsy performs all speech-to-text transcription <strong>entirely on your device</strong> using
                Apple CoreML via the open-source WhisperKit library. <strong>No audio data, transcription data,
                or any personal data is sent to any third-party AI service</strong> (such as OpenAI, Google Cloud Speech,
                or any other external AI provider) for transcription purposes.
              </p>
            </div>
            <p className="text-gray-700 leading-relaxed mb-4">
              The AI model used for transcription is downloaded once to your device (~150 MB) from a public model
              repository (HuggingFace). During this download, <strong>no user data is transmitted</strong> — only the
              model weights are downloaded to your device.
            </p>
            <p className="text-gray-700 leading-relaxed">
              After the initial download, all transcription works completely offline without any internet connection.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">3. Information We Collect</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We collect the following types of information:
            </p>

            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Account Information (optional)</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Email address (from Apple ID or Google account)</li>
                  <li>Display name</li>
                  <li>User ID</li>
                </ul>
                <p className="text-gray-600 text-sm mt-1 ml-4">
                  Collected only when you choose to sign in. The app can be used without an account.
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
                  <li>If you sign in, transcription text is synced to our server (Supabase) for cross-device access</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Usage Data</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>App usage frequency</li>
                  <li>Feature usage statistics</li>
                  <li>Device type and operating system version</li>
                </ul>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">4. How We Use Your Information</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>On-Device Transcription:</strong> Audio is processed locally using Apple CoreML to generate transcription text. No data leaves your device during this process.</li>
              <li><strong>Authentication:</strong> To verify your identity and manage your account (if you choose to sign in)</li>
              <li><strong>Data Synchronization:</strong> To sync your transcription text across devices (only when signed in)</li>
              <li><strong>Service Improvement:</strong> Anonymized usage data to improve our services</li>
              <li><strong>Customer Support:</strong> To respond to your inquiries</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">5. Data Storage</h2>

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
                  <li>Transcription text (for cross-device sync)</li>
                  <li><strong className="text-green-700">Audio recordings are never uploaded to the cloud</strong></li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Security Measures</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>All data is transferred over encrypted connections (HTTPS/TLS)</li>
                  <li>Data at rest is encrypted</li>
                  <li>Row-level security ensures you can only access your own data</li>
                </ul>
              </div>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">6. Third-Party Services</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We use the following third-party services. <strong>None of these services receive your audio recordings
              or are used for AI transcription.</strong>
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
            <div className="bg-green-50 border-l-4 border-green-500 p-4 mt-4">
              <p className="text-green-800 font-semibold">
                No third-party AI service (such as OpenAI, Google Cloud, or any other external AI provider)
                is used for transcription or any other processing of user data. All AI processing happens
                on-device using Apple CoreML.
              </p>
            </div>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">7. Data Sharing</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We do <strong>not</strong> sell, rent, or share your personal information with third parties, except in the following circumstances:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>With Your Consent:</strong> When you explicitly authorize sharing</li>
              <li><strong>Service Providers:</strong> Third-party services listed above, solely for providing our services (authentication and data sync)</li>
              <li><strong>Legal Requirements:</strong> To comply with applicable laws, regulations, or legal processes</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4 font-semibold">
              Your audio recordings are never shared with anyone. They exist only on your device.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">8. User Consent</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Before using Lecsy, we obtain your explicit consent through our in-app privacy consent screen, which clearly explains:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>That all AI transcription is performed on-device using Apple CoreML</li>
              <li>That no third-party AI service is used</li>
              <li>That audio recordings never leave your device</li>
              <li>That internet is used only for the one-time AI model download (no user data transmitted)</li>
              <li>That signing in enables optional cloud sync of transcription text only</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              Users must agree to these terms before using the app&apos;s transcription features.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">9. Your Rights</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              You have the following rights regarding your personal data:
            </p>
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
                <p className="text-gray-700">You can delete your account and all associated data from within the app (Settings &gt; Delete Account).</p>
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Right to Data Portability</h3>
                <p className="text-gray-700">You can request a copy of your data in a portable format.</p>
              </div>
            </div>
            <p className="text-gray-700 leading-relaxed mt-4">
              <strong>How to Exercise Your Rights:</strong> Contact us at{' '}
              <a href="mailto:nittonotakumi@gmail.com" className="text-blue-600 hover:underline">
                nittonotakumi@gmail.com
              </a>
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">10. Data Retention</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>On-device data (audio, transcripts) remains until you delete it</li>
              <li>Cloud data is retained while your account is active</li>
              <li>Upon account deletion, all cloud data is deleted within 30 days</li>
              <li>Some data may be retained longer if required by law</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">11. Security</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Encryption in Transit:</strong> All communications use HTTPS/TLS</li>
              <li><strong>Encryption at Rest:</strong> Cloud data is encrypted when stored</li>
              <li><strong>Access Controls:</strong> Row-level security ensures data isolation</li>
              <li><strong>On-Device Security:</strong> Audio and local data are protected by iOS device security</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">12. Children&apos;s Privacy</h2>
            <p className="text-gray-700 leading-relaxed">
              Lecsy is not intended for children under the age of 13. We do not knowingly collect personal
              information from children under 13. If you believe we have collected information from a child under 13,
              please contact us immediately.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">13. International Data Transfers</h2>
            <p className="text-gray-700 leading-relaxed">
              If you sign in, your transcription text may be transferred to and processed in countries other
              than your country of residence via our cloud provider (Supabase). By using the sync feature,
              you consent to such transfers. Audio recordings are never transferred internationally as they
              remain on your device.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">14. Changes to This Policy</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We may update this Privacy Policy from time to time. We will notify you of significant changes through:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>In-app notifications</li>
              <li>Updating the &ldquo;Last Updated&rdquo; date above</li>
            </ul>
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
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">17. Contact Us</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you have any questions about this Privacy Policy, please contact us:
            </p>
            <p className="text-gray-700">
              <strong>Email:</strong>{' '}
              <a href="mailto:nittonotakumi@gmail.com" className="text-blue-600 hover:underline">
                nittonotakumi@gmail.com
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
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">On-device AI transcription (Apple CoreML)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Your device only</td>
                    <td className="px-4 py-3 text-sm font-semibold text-green-700 border-b">No one</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcription text</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Display, search, cross-device sync</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Device + cloud (if signed in)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Supabase (our cloud provider)</td>
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
                <li className="text-green-700">&#10003; All AI transcription is on-device (Apple CoreML) — no third-party AI service</li>
                <li className="text-green-700">&#10003; Audio recordings never leave your device</li>
                <li className="text-green-700">&#10003; Cloud sync is optional and only for transcription text</li>
                <li className="text-green-700">&#10003; No data is sold to third parties</li>
                <li className="text-green-700">&#10003; You can delete your data anytime</li>
              </ul>
            </div>
          </section>

          <div className="border-t pt-8 mt-8">
            <p className="text-gray-600 text-sm mb-4 italic">
              This Privacy Policy is effective as of March 3, 2026.
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
