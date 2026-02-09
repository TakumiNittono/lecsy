import type { Metadata } from 'next';
import SEOPageLayout from '@/components/SEOPageLayout';
import FAQSection from '@/components/FAQSection';
import ComparisonTable from '@/components/ComparisonTable';
import Link from 'next/link';

export const metadata: Metadata = {
  title: "Best Otter.ai Alternative for Lectures – Lecsy vs Otter vs Notta (2026)",
  description: "Looking for an Otter.ai alternative for college lectures? Compare Lecsy, Otter, and Notta side-by-side. Offline transcription, privacy-first, built for students.",
  alternates: {
    canonical: "https://www.lecsy.app/otter-alternative-for-lectures",
  },
  openGraph: {
    title: "Best Otter.ai Alternative for Lectures (2026) | Lecsy",
    description: "Lecsy vs Otter vs Notta: Which lecture transcription app is best for students?",
    url: "https://www.lecsy.app/otter-alternative-for-lectures",
  },
};

const faqs = [
  {
    question: "Is Lecsy really free?",
    answer: "Yes! Lecsy offers unlimited recording and transcription for free forever. Pro features (AI summaries, exam prep mode) are $2.99/month — much more affordable than Otter's $16.99/month or Notta's $13.99/month."
  },
  {
    question: "How does offline transcription work?",
    answer: "Lecsy uses on-device AI processing. Your iPhone handles all transcription locally — no internet connection needed. This means faster transcription, better privacy, and no data charges. Otter and Notta require internet and process everything in the cloud."
  },
  {
    question: "Can Lecsy replace Otter for meetings too?",
    answer: "Lecsy is optimized for academic lectures, seminars, and labs. While it can record any audio, it's designed specifically for students. Otter is built for business meetings. For college lectures, Lecsy is the better choice — offline, private, and affordable."
  },
  {
    question: "What if I need multi-language support?",
    answer: "Lecsy currently supports English and Japanese transcription. Otter supports more languages, but requires internet. If you need multi-language support for offline use, Lecsy is still the best option for English lectures."
  },
  {
    question: "Why should I switch from Otter to Lecsy?",
    answer: "If you're a student recording college lectures, Lecsy offers: offline functionality (no Wi-Fi needed), local processing (better privacy), student-focused features (exam prep mode), and much lower cost ($2.99/month vs $16.99/month). Otter is designed for business, Lecsy is built for students."
  }
];

const comparisonRows = [
  {
    feature: "Price",
    lecsy: "Free (Pro $2.99/mo)",
    otter: "Free limited, $16.99/mo",
    notta: "Free limited, $13.99/mo"
  },
  {
    feature: "Offline Recording",
    lecsy: true,
    otter: false,
    notta: false
  },
  {
    feature: "Offline Transcription",
    lecsy: true,
    otter: false,
    notta: false
  },
  {
    feature: "Privacy (Local Processing)",
    lecsy: true,
    otter: false,
    notta: false
  },
  {
    feature: "Built for Students",
    lecsy: true,
    otter: false,
    notta: false
  },
  {
    feature: "iPhone App",
    lecsy: true,
    otter: true,
    notta: true
  },
  {
    feature: "AI Summary",
    lecsy: "✅ (Pro)",
    otter: "✅ (Paid)",
    notta: "✅ (Paid)"
  },
  {
    feature: "Exam Prep Mode",
    lecsy: "✅ (Pro)",
    otter: false,
    notta: false
  },
  {
    feature: "Languages",
    lecsy: "EN, JP",
    otter: "EN + others",
    notta: "EN + others"
  }
];

const breadcrumbs = [
  { name: "Home", url: "https://www.lecsy.app/" },
  { name: "Otter Alternative for Lectures", url: "https://www.lecsy.app/otter-alternative-for-lectures" }
];

export default function OtterAlternativeForLecturesPage() {
  return (
    <SEOPageLayout breadcrumbs={breadcrumbs}>
      {/* Hero */}
      <section className="bg-gradient-to-br from-blue-50 via-white to-blue-50 py-16 lg:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl lg:text-6xl font-bold text-gray-900 mb-6 text-center">
            Best Otter.ai Alternative for College Lectures (2026)
          </h1>
          <p className="text-xl text-gray-600 mb-8 text-center max-w-3xl mx-auto">
            Looking for an Otter.ai alternative? Compare Lecsy, Otter, and Notta side-by-side. Find the best lecture transcription app for students.
          </p>
        </div>
      </section>

      {/* Why Students Are Looking */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why Students Are Looking for Otter Alternatives
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">Otter's free plan is too limited.</strong> Free Otter accounts get only 300 minutes per month — that's about 5 hours of lectures. For students taking multiple classes, this runs out quickly. Unlimited transcription requires $16.99/month.
            </p>
            <p>
              <strong className="text-gray-900">Internet is required.</strong> Otter needs an internet connection for both recording and transcription. Lecture halls often have poor Wi-Fi, and international students may have limited data plans. Offline functionality is essential.
            </p>
            <p>
              <strong className="text-gray-900">Privacy concerns.</strong> Otter processes all audio in the cloud. For students recording academic lectures, this raises privacy and data security concerns. Some universities have policies against cloud-based recording.
            </p>
            <p>
              <strong className="text-gray-900">Not optimized for university lectures.</strong> Otter is designed for business meetings, not academic lectures. It lacks student-specific features like exam prep mode and academic terminology optimization.
            </p>
          </div>
        </div>
      </section>

      {/* Detailed Comparison */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8 text-center">
            Lecsy vs Otter vs Notta – Detailed Comparison
          </h2>
          <ComparisonTable rows={comparisonRows} includeNotta={true} />
        </div>
      </section>

      {/* Why Lecsy Wins for College Lectures */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why Lecsy Wins for College Lectures
          </h2>
          <div className="space-y-6">
            <div className="bg-blue-50 border-l-4 border-blue-600 p-6 rounded-r-lg">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Offline = Lecture Hall Wi-Fi Problems Solved</h3>
              <p className="text-gray-700">
                Many lecture halls have unreliable Wi-Fi. With Lecsy, you don't need internet at all. Record and transcribe completely offline. Otter and Notta require constant internet connection.
              </p>
            </div>
            <div className="bg-sky-50 border-l-4 border-sky-600 p-6 rounded-r-lg">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Local Processing = University Policy Compliance</h3>
              <p className="text-gray-700">
                Some universities restrict cloud-based recording due to privacy concerns. Lecsy processes everything locally on your iPhone, ensuring compliance with university policies and protecting your data.
              </p>
            </div>
            <div className="bg-cyan-50 border-l-4 border-cyan-600 p-6 rounded-r-lg">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Student-Focused Pricing</h3>
              <p className="text-gray-700">
                Lecsy is free forever for basic features. Pro is $2.99/month. Otter charges $16.99/month for unlimited transcription — over 5x more expensive. Notta charges $13.99/month — still 4x more expensive.
              </p>
            </div>
            <div className="bg-purple-50 border-l-4 border-purple-600 p-6 rounded-r-lg">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Exam Prep Mode</h3>
              <p className="text-gray-700">
                Lecsy Pro includes Exam Mode — AI generates Q&A, predicts exam topics, and helps you study efficiently. Otter and Notta don't have student-specific features like this.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Why Lecsy Wins for International Students */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why Lecsy Wins for International Students
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">English lecture transcription → review at your own pace.</strong> International students struggle with fast-paced English lectures. Lecsy records everything, transcribes it, and lets you review at your comfortable reading speed. Otter requires internet, which may not be reliable or affordable.
            </p>
            <p>
              <strong className="text-gray-900">Cheap SIM cards work fine.</strong> Lecsy works offline, so you don't need expensive data plans. International students often use budget SIM cards or limited data — Lecsy doesn't require any internet connection.
            </p>
            <p>
              <strong className="text-gray-900">Privacy-first approach.</strong> Your audio never leaves your iPhone. For international students concerned about data privacy, Lecsy's local processing is a major advantage over cloud-based Otter and Notta.
            </p>
          </div>
        </div>
      </section>

      {/* How to Switch */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How to Switch from Otter to Lecsy
          </h2>
          <div className="bg-gray-50 p-8 rounded-xl space-y-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-blue-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">1</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Download Lecsy</h3>
                <p className="text-gray-700">Get Lecsy from the App Store (free). No account required to start.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-sky-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">2</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Record Your First Lecture</h3>
                <p className="text-gray-700">Try recording a lecture with Lecsy. You'll notice it works offline and transcribes faster than Otter.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-cyan-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">3</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Compare the Experience</h3>
                <p className="text-gray-700">See how Lecsy's offline transcription compares to Otter's cloud-based approach. Notice the speed and privacy benefits.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-purple-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">4</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Cancel Otter, Keep Lecsy</h3>
                <p className="text-gray-700">Once you're comfortable with Lecsy, cancel your Otter subscription and save $14/month. Lecsy Pro is just $2.99/month.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Internal Links */}
      <section className="py-12 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">Related Resources</h2>
          <div className="grid md:grid-cols-2 gap-4">
            <Link
              href="/ai-transcription-for-students"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Transcription for Students</h3>
              <p className="text-sm text-gray-600">Learn how AI transcription helps college students understand lectures better.</p>
            </Link>
            <Link
              href="/ai-note-taking-for-international-students"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Note Taking for International Students</h3>
              <p className="text-sm text-gray-600">Specifically designed for ESL students struggling with English lectures.</p>
            </Link>
            <Link
              href="/lecture-recording-app-college"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Lecture Recording App for College</h3>
              <p className="text-sm text-gray-600">Learn how to record different types of classes effectively.</p>
            </Link>
            <Link
              href="/how-to-record-lectures-legally"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">How to Record Lectures Legally</h3>
              <p className="text-sm text-gray-600">Everything you need to know about recording college lectures legally.</p>
            </Link>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <FAQSection faqs={faqs} />
    </SEOPageLayout>
  );
}
