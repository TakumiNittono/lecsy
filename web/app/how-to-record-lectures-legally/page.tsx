import type { Metadata } from 'next';
import SEOPageLayout from '@/components/SEOPageLayout';
import FAQSection from '@/components/FAQSection';
import Link from 'next/link';

export const metadata: Metadata = {
  title: "How to Record Lectures Legally – Student Guide (2026)",
  description: "Is it legal to record college lectures? Learn the rules, get professor permission, and record lectures the right way. A complete guide for US college and international students.",
  alternates: {
    canonical: "https://www.lecsy.app/how-to-record-lectures-legally",
  },
  openGraph: {
    title: "How to Record Lectures Legally – Student Guide (2026) | Lecsy",
    description: "Everything students need to know about recording college lectures legally in the US.",
    url: "https://www.lecsy.app/how-to-record-lectures-legally",
  },
};

const faqs = [
  {
    question: "Can I share recorded lectures?",
    answer: "Generally, no. Recorded lectures are for personal study purposes only. Sharing recordings with classmates or posting them online without permission violates most university policies and copyright laws. Always respect your professor's recording policy."
  },
  {
    question: "What if my professor says no?",
    answer: "If your professor explicitly prohibits recording, you must respect that decision. However, you can request accommodation through your university's disability services office if you have a documented need (e.g., learning disability, hearing impairment)."
  },
  {
    question: "Do I need to tell classmates?",
    answer: "It depends on your state's recording laws and university policy. In one-party consent states, you typically don't need to inform classmates. However, it's courteous to let them know, especially in small seminars. Always check your university's specific policy."
  },
  {
    question: "Is it different in other countries?",
    answer: "Yes, recording laws vary by country. This guide focuses on US law. In some countries (e.g., some European countries), all-party consent is required. Always research local laws and university policies when studying abroad."
  },
  {
    question: "Can I use recordings for exam prep?",
    answer: "Yes, personal study and exam preparation are typically allowed uses of lecture recordings. However, you cannot use recordings to create study guides for sale, share with future students, or use during exams (unless explicitly permitted)."
  }
];

const breadcrumbs = [
  { name: "Home", url: "https://www.lecsy.app/" },
  { name: "How to Record Lectures Legally", url: "https://www.lecsy.app/how-to-record-lectures-legally" }
];

export default function HowToRecordLecturesLegallyPage() {
  return (
    <SEOPageLayout breadcrumbs={breadcrumbs}>
      {/* Hero */}
      <section className="bg-gradient-to-br from-blue-50 via-white to-blue-50 py-16 lg:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl lg:text-6xl font-bold text-gray-900 mb-6 text-center">
            How to Record College Lectures Legally (2026 Guide)
          </h1>
          <p className="text-xl text-gray-600 mb-8 text-center max-w-3xl mx-auto">
            Is it legal to record lectures? Learn the rules, get permission, and record responsibly. A complete guide for US college and international students.
          </p>
        </div>
      </section>

      {/* Is It Legal */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Is It Legal to Record Lectures in the US?
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">Federal law: Generally yes.</strong> Under federal law, recording conversations is legal if at least one party (you) consents. Since you're recording, you've given consent. This is called "one-party consent."
            </p>
            <p>
              <strong className="text-gray-900">State laws vary.</strong> Most US states follow one-party consent, meaning you can record if you're part of the conversation. However, some states (like California, Florida, Illinois) require "all-party consent" in certain situations. Always check your state's specific laws.
            </p>
            <p>
              <strong className="text-gray-900">University policies override.</strong> Even if recording is legal under state law, your university may have its own policies. University policies take precedence — if your school prohibits recording, you must follow that rule.
            </p>
            <div className="bg-yellow-50 border-l-4 border-yellow-600 p-6 rounded-r-lg mt-6">
              <p className="text-gray-800">
                <strong>Important:</strong> This guide provides general information, not legal advice. Always check your specific university's policy and consult with your professor or student services office.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* University Policies */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            University Recording Policies: What You Need to Know
          </h2>
          <div className="space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-md">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Common University Rules</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Recording is allowed for personal study purposes</li>
                <li>You must get professor permission (explicit or implicit)</li>
                <li>Recordings cannot be shared or distributed</li>
                <li>Recordings cannot be used during exams (unless permitted)</li>
                <li>Some universities require disability services approval</li>
              </ul>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-md">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Check Your Syllabus</h3>
              <p className="text-gray-700 mb-3">
                Many professors include recording policies in their course syllabus. Look for sections like:
              </p>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>"Recording Policy"</li>
                <li>"Classroom Recording"</li>
                <li>"Academic Integrity"</li>
                <li>"Course Policies"</li>
              </ul>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-md">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Academic Integrity Connection</h3>
              <p className="text-gray-700">
                Recording policies are often tied to academic integrity. Using recordings inappropriately (e.g., sharing with future students, using during exams) can violate academic integrity policies and result in serious consequences.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How to Get Permission */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How to Get Professor Permission
          </h2>
          <div className="space-y-8">
            <div className="bg-gray-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Email Template</h3>
              <div className="bg-white p-4 rounded border border-gray-200 text-sm text-gray-700 font-mono">
                <p>Subject: Request to Record Lectures</p>
                <br />
                <p>Dear Professor [Name],</p>
                <br />
                <p>I hope this email finds you well. I am writing to request permission to record your [Course Name] lectures for personal study purposes.</p>
                <br />
                <p>I find that recording lectures helps me better understand the material, especially when reviewing complex concepts. I assure you that:</p>
                <ul className="list-disc list-inside ml-4">
                  <li>The recordings will be used solely for my personal study</li>
                  <li>I will not share or distribute the recordings</li>
                  <li>I will not use recordings during exams unless explicitly permitted</li>
                </ul>
                <br />
                <p>Thank you for considering my request. Please let me know if you have any questions or concerns.</p>
                <br />
                <p>Best regards,<br />[Your Name]</p>
              </div>
            </div>
            <div className="bg-gray-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Asking Directly</h3>
              <p className="text-gray-700 mb-3">
                If you prefer to ask in person, approach your professor before or after class:
              </p>
              <p className="text-gray-700 italic">
                "Hi Professor [Name], I was wondering if I could record your lectures for personal study. I find it helpful for reviewing complex material. I won't share the recordings with anyone."
              </p>
            </div>
            <div className="bg-gray-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Through Disability Services</h3>
              <p className="text-gray-700">
                If you have a documented learning disability, hearing impairment, or other accommodation need, your university's disability services office can help. They can provide official approval and communicate with professors on your behalf.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* International Students */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Special Considerations for International Students
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">Your rights are the same.</strong> International students have the same rights as domestic students regarding lecture recording. University policies apply equally to all students.
            </p>
            <p>
              <strong className="text-gray-900">Accommodation requests are valid.</strong> If English is not your first language and you struggle with fast-paced lectures, you can request accommodation through disability services. Many universities recognize language barriers as a valid reason for recording permission.
            </p>
            <p>
              <strong className="text-gray-900">Cultural differences in recording.</strong> In some countries, recording lectures is uncommon or discouraged. In the US, recording for personal study is generally accepted, but always get permission first.
            </p>
            <div className="bg-blue-50 border-l-4 border-blue-600 p-6 rounded-r-lg mt-6">
              <p className="text-gray-800">
                <strong>Tip for international students:</strong> If you're uncomfortable asking directly, use the email template above. It's professional and clearly states your intentions. Most professors are understanding and will grant permission.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Best Practices */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Best Practices for Recording Lectures
          </h2>
          <div className="space-y-6">
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white font-bold flex-shrink-0">✓</div>
              <div>
                <h3 className="text-lg font-bold text-gray-900 mb-2">Get Permission First</h3>
                <p className="text-gray-700">Always ask your professor before recording. Don't assume it's okay, even if other students are recording.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white font-bold flex-shrink-0">✓</div>
              <div>
                <h3 className="text-lg font-bold text-gray-900 mb-2">Keep It Personal</h3>
                <p className="text-gray-700">Use recordings only for your own study. Don't share with classmates, post online, or create study guides for sale.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white font-bold flex-shrink-0">✓</div>
              <div>
                <h3 className="text-lg font-bold text-gray-900 mb-2">Respect Privacy</h3>
                <p className="text-gray-700">Be mindful of classmates' privacy. If discussions involve personal information, consider pausing recording during those sections.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white font-bold flex-shrink-0">✓</div>
              <div>
                <h3 className="text-lg font-bold text-gray-900 mb-2">Use Lecsy for Privacy</h3>
                <p className="text-gray-700">Lecsy processes everything locally on your iPhone. Your audio never leaves your device, ensuring better privacy and compliance with university policies.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* How Lecsy Helps */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How Lecsy Helps You Record Responsibly
          </h2>
          <div className="bg-white p-8 rounded-xl shadow-md space-y-6">
            <div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">Audio Stays on Your Device</h3>
              <p className="text-gray-700">
                Lecsy processes all audio locally on your iPhone. Your recordings never leave your device, ensuring maximum privacy and compliance with university policies that restrict cloud-based recording.
              </p>
            </div>
            <div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">Sharing Features Are Intentionally Limited</h3>
              <p className="text-gray-700">
                Lecsy is designed for personal study. While you can copy text from transcripts, sharing full recordings is intentionally difficult — encouraging responsible use.
              </p>
            </div>
            <div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">Study-Focused Design</h3>
              <p className="text-gray-700">
                Lecsy is built specifically for students studying lectures. It's not designed for sharing or distribution, helping you stay compliant with university policies.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Internal Links */}
      <section className="py-12 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">Related Resources</h2>
          <div className="grid md:grid-cols-2 gap-4">
            <Link
              href="/lecture-recording-app-college"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Lecture Recording App for College</h3>
              <p className="text-sm text-gray-600">Learn how to record different types of classes effectively.</p>
            </Link>
            <Link
              href="/ai-transcription-for-students"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Transcription for Students</h3>
              <p className="text-sm text-gray-600">Learn how AI transcription helps college students understand lectures better.</p>
            </Link>
            <Link
              href="/ai-note-taking-for-international-students"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Note Taking for International Students</h3>
              <p className="text-sm text-gray-600">Specifically designed for ESL students struggling with English lectures.</p>
            </Link>
            <Link
              href="/otter-alternative-for-lectures"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Otter Alternative for Lectures</h3>
              <p className="text-sm text-gray-600">Compare Lecsy with other lecture recording apps.</p>
            </Link>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <FAQSection faqs={faqs} />
    </SEOPageLayout>
  );
}
