'use client';

import Link from 'next/link';

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8 md:p-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Privacy Policy</h1>
          
          <p className="text-gray-600 mb-8 text-sm">
            <strong>Last Updated:</strong> January 28, 2026
          </p>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">1. Introduction</h2>
            <p className="text-gray-700 leading-relaxed">
              lecsy ("the App") respects your privacy and is committed to protecting your personal information. 
              This Privacy Policy explains what information we collect, how we use it, and your rights regarding your data.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">2. Information We Collect</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We may collect the following types of information:
            </p>
            
            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Account Information</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Email address</li>
                  <li>Display name (obtained from Apple ID or Google account)</li>
                  <li>User ID</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Audio Data</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Recorded lecture audio</li>
                  <li><strong className="text-red-600">Important:</strong> Audio is processed entirely on your device and is never sent to our servers</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">Transcript Data</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Text generated from speech recognition</li>
                  <li>Stored on our servers only when you explicitly choose to save to the web</li>
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
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">3. How We Use Your Information</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We use the collected information for the following purposes:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Service Provision:</strong> To provide and improve our services</li>
              <li><strong>Authentication:</strong> To verify your identity and manage your account</li>
              <li><strong>Data Synchronization:</strong> To sync your transcripts across devices</li>
              <li><strong>Customer Support:</strong> To respond to your inquiries and provide assistance</li>
              <li><strong>Service Notifications:</strong> To send important updates about the service</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">4. Audio Data Processing</h2>
            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-4">
              <p className="text-blue-800 font-semibold mb-2">Important Notice:</p>
              <p className="text-blue-900 leading-relaxed">
                lecsy does <strong>not</strong> send your audio data to any server. All speech recognition (transcription) 
                processing is performed locally on your device using offline technology. This ensures your lecture content remains private.
              </p>
            </div>
            <p className="text-gray-700 leading-relaxed">
              Only the text transcription is saved to our servers, and only when you explicitly tap "Save to Web."
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">5. Data Storage</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Your data is stored in the following locations:
            </p>
            
            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">On Your Device</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Recording files (.m4a audio)</li>
                  <li>Local copies of transcription text</li>
                  <li>App settings and preferences</li>
                </ul>
              </div>

              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">In the Cloud (Supabase)</h3>
                <ul className="list-disc list-inside text-gray-700 space-y-1 ml-4">
                  <li>Account information</li>
                  <li>Transcription text (when saved to web)</li>
                  <li>Subscription information</li>
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
              We use the following third-party services:
            </p>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 border border-gray-300">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Service</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Purpose</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Privacy Policy</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Supabase</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Database and authentication</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://supabase.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        supabase.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Apple Sign In</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">User authentication</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://www.apple.com/privacy/" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        apple.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Google Sign In</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">User authentication</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        policies.google.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>Stripe</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Payment processing (Pro subscription)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://stripe.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        stripe.com/privacy
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b"><strong>OpenAI</strong></td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">AI summarization (Pro only)</td>
                    <td className="px-4 py-3 text-sm text-blue-600 border-b">
                      <a href="https://openai.com/privacy" target="_blank" rel="noopener noreferrer" className="hover:underline">
                        openai.com/privacy
                      </a>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p className="text-gray-700 leading-relaxed mt-4 text-sm italic">
              <strong>Note:</strong> OpenAI processes only your transcription text (not audio) and only when you use the AI Summary feature (Pro plan only).
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">7. Data Sharing</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We do <strong>not</strong> sell, rent, or share your personal information with third parties, except in the following circumstances:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>With Your Consent:</strong> When you explicitly authorize sharing</li>
              <li><strong>Legal Requirements:</strong> To comply with applicable laws, regulations, or legal processes</li>
              <li><strong>Service Providers:</strong> Third-party services listed above, solely for providing our services</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">8. Your Rights</h2>
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
                <p className="text-gray-700">You can request deletion of your account and all associated data.</p>
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
              </a>{' '}
              to exercise any of these rights.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">9. Data Retention</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>We retain your data while your account is active</li>
              <li>Upon account deletion request, all data is deleted within 30 days</li>
              <li>Some data may be retained longer if required by law</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">10. Security</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We implement industry-standard security measures to protect your data:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Encryption in Transit:</strong> All communications use HTTPS/TLS</li>
              <li><strong>Encryption at Rest:</strong> Data is encrypted when stored</li>
              <li><strong>Access Controls:</strong> Strict access controls and authentication</li>
              <li><strong>Regular Audits:</strong> Periodic security reviews and updates</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              While we strive to protect your data, no method of transmission over the Internet is 100% secure. 
              We cannot guarantee absolute security.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">11. Children's Privacy</h2>
            <p className="text-gray-700 leading-relaxed">
              lecsy is not intended for children under the age of 13. We do not knowingly collect personal 
              information from children under 13. If you believe we have collected information from a child under 13, 
              please contact us immediately.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">12. International Data Transfers</h2>
            <p className="text-gray-700 leading-relaxed">
              Your data may be transferred to and processed in countries other than your country of residence. 
              These countries may have different data protection laws. By using the App, you consent to such transfers.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">13. Changes to This Policy</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              We may update this Privacy Policy from time to time. We will notify you of significant changes through:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>In-app notifications</li>
              <li>Email (if you have provided one)</li>
              <li>Updating the "Last Updated" date above</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              We encourage you to review this policy periodically.
            </p>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">14. California Privacy Rights (CCPA)</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA):
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
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">15. European Privacy Rights (GDPR)</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you are in the European Economic Area (EEA), you have rights under the General Data Protection Regulation (GDPR):
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4 mb-4">
              <li>Right to access, rectification, and erasure</li>
              <li>Right to restrict processing</li>
              <li>Right to data portability</li>
              <li>Right to object to processing</li>
              <li>Right to lodge a complaint with a supervisory authority</li>
            </ul>
            <p className="text-gray-700 leading-relaxed">
              <strong>Legal Basis for Processing:</strong> We process your data based on:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4 mt-2">
              <li>Your consent</li>
              <li>Performance of a contract (providing the service)</li>
              <li>Legitimate interests (improving our service)</li>
            </ul>
          </section>

          <section className="mb-10">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">16. Contact Us</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              If you have any questions, concerns, or requests regarding this Privacy Policy, please contact us:
            </p>
            <p className="text-gray-700">
              <strong>Email:</strong>{' '}
              <a href="mailto:nittonotakumi@gmail.com" className="text-blue-600 hover:underline">
                nittonotakumi@gmail.com
              </a>
            </p>
          </section>

          <section className="mb-10 bg-gray-50 p-6 rounded-lg">
            <h2 className="text-2xl font-semibold text-gray-800 mb-4">17. Summary</h2>
            <div className="overflow-x-auto mb-4">
              <table className="min-w-full divide-y divide-gray-200 border border-gray-300">
                <thead className="bg-gray-100">
                  <tr>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">What We Collect</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">How We Use It</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700 border-b">Who Has Access</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Account info (email, name)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Authentication, support</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Only you and our service</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Audio recordings</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcription (on-device only)</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Only you (never uploaded)</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Transcription text</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Web sync, AI features</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">You, and our service providers</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Usage data</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Service improvement</td>
                    <td className="px-4 py-3 text-sm text-gray-700 border-b">Anonymized and aggregated</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="mt-4">
              <p className="text-gray-800 font-semibold mb-2">Key Points:</p>
              <ul className="list-none space-y-1">
                <li className="text-green-700">✅ Audio never leaves your device</li>
                <li className="text-green-700">✅ Text saved only when you choose</li>
                <li className="text-green-700">✅ No data sold to third parties</li>
                <li className="text-green-700">✅ You can delete your data anytime</li>
              </ul>
            </div>
          </section>

          <div className="border-t pt-8 mt-8">
            <p className="text-gray-600 text-sm mb-4 italic">
              This Privacy Policy is effective as of January 28, 2026.
            </p>
            <Link href="/" className="text-blue-600 hover:text-blue-800 font-medium inline-flex items-center">
              <span>←</span>
              <span className="ml-2">Back to Home</span>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
