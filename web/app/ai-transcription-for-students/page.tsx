import type { Metadata } from 'next';
import SEOPageLayout from '@/components/SEOPageLayout';
import FAQSection from '@/components/FAQSection';
import ComparisonTable from '@/components/ComparisonTable';
import Link from 'next/link';

export const metadata: Metadata = {
  title: "AI Transcription for Students – Understand College Lectures Better",
  description: "Struggling to keep up with fast-paced college lectures? Lecsy's AI transcription app records and transcribes lectures offline on your iPhone. Built for college and international students.",
  alternates: {
    canonical: "https://www.lecsy.app/ai-transcription-for-students",
  },
  openGraph: {
    title: "AI Transcription for Students – Understand College Lectures Better | Lecsy",
    description: "Record and transcribe college lectures with AI. Offline, private, and built for students.",
    url: "https://www.lecsy.app/ai-transcription-for-students",
  },
};

const faqs = [
  {
    question: "Is AI transcription accurate?",
    answer: "Yes! Lecsy uses advanced on-device AI transcription that achieves high accuracy for clear speech. While no transcription is 100% perfect, Lecsy's local processing ensures fast, reliable results without internet dependency."
  },
  {
    question: "Does it work without internet?",
    answer: "Absolutely. Lecsy's AI transcription works completely offline. Record your lecture, and transcription happens right on your iPhone — no Wi-Fi or cellular data needed. Perfect for lecture halls with poor connectivity."
  },
  {
    question: "Can I use it for study groups?",
    answer: "Yes, Lecsy is great for study groups. Each member can record their own lectures and share transcripts. However, remember to always get permission from professors before recording, especially in group settings."
  },
  {
    question: "What about professors who speak fast?",
    answer: "That's exactly why Lecsy exists! Fast-speaking professors are a common challenge. With Lecsy, you can record everything, transcribe it, and review at your own pace. No more missing important points because you couldn't keep up."
  },
  {
    question: "How is this different from Zoom transcription?",
    answer: "Zoom transcription only works for online classes. Lecsy works for in-person lectures, seminars, and labs. Plus, Lecsy processes everything locally on your device, so your audio never leaves your iPhone — better privacy and works offline."
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
  }
];

const breadcrumbs = [
  { name: "Home", url: "https://www.lecsy.app/" },
  { name: "AI Transcription for Students", url: "https://www.lecsy.app/ai-transcription-for-students" }
];

export default function AITranscriptionForStudentsPage() {
  return (
    <SEOPageLayout breadcrumbs={breadcrumbs}>
      {/* Hero */}
      <section className="bg-gradient-to-br from-blue-50 via-white to-blue-50 py-16 lg:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl lg:text-6xl font-bold text-gray-900 mb-6 text-center">
            AI Transcription App for College Students
          </h1>
          <p className="text-xl text-gray-600 mb-8 text-center max-w-3xl mx-auto">
            Stop struggling with fast-paced lectures. Record, transcribe, and review every word with AI-powered transcription built for students.
          </p>
        </div>
      </section>

      {/* Why Students Struggle */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why College Students Struggle With Lectures
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">90-minute lectures pack in hours of information.</strong> In a typical college lecture, professors cover multiple concepts, examples, and details. Even the best note-takers miss important points.
            </p>
            <p>
              <strong className="text-gray-900">Fast-speaking professors are common.</strong> Many professors speak quickly, especially when covering complex material. By the time you finish writing one point, they've moved on to the next.
            </p>
            <p>
              <strong className="text-gray-900">English isn't everyone's first language.</strong> International and ESL students face an extra challenge: processing fast-paced English while trying to take notes. Many students report missing 30-50% of lecture content.
            </p>
            <p>
              <strong className="text-gray-900">Handwritten notes have limits.</strong> You can't write as fast as professors speak. Trying to capture everything means you're not actually listening and understanding — you're just transcribing.
            </p>
            <div className="bg-blue-50 border-l-4 border-blue-600 p-6 rounded-r-lg mt-8">
              <p className="text-gray-800 italic">
                "I used to miss half of what my professor said in History 101. Even with detailed notes, I'd realize later that I'd missed crucial context. Lecsy changed everything — now I can focus on understanding during class and review the full transcript later."
              </p>
              <p className="text-sm text-gray-600 mt-2">— College student, UC Berkeley</p>
            </div>
          </div>
        </div>
      </section>

      {/* How AI Transcription Solves This */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How AI Transcription Solves This
          </h2>
          <div className="space-y-8">
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Record → Transcribe → Review Workflow</h3>
              <p className="text-lg text-gray-700 mb-4">
                With AI transcription, you don't need to frantically write notes during class. Here's how it works:
              </p>
              <ol className="list-decimal list-inside space-y-3 text-gray-700">
                <li><strong className="text-gray-900">Record the lecture</strong> — Open Lecsy, tap record, and focus on listening.</li>
                <li><strong className="text-gray-900">AI transcribes automatically</strong> — After recording, Lecsy transcribes everything on your iPhone (no internet needed).</li>
                <li><strong className="text-gray-900">Review at your pace</strong> — Read the full transcript on the web, search for keywords, and copy important sections.</li>
                <li><strong className="text-gray-900">Study effectively</strong> — Use AI summaries (Pro feature) to extract key points and prepare for exams.</li>
              </ol>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Works Completely Offline</h3>
              <p className="text-lg text-gray-700">
                Unlike cloud-based transcription services, Lecsy processes everything locally on your iPhone. This means:
              </p>
              <ul className="list-disc list-inside space-y-2 text-gray-700 mt-4">
                <li>No Wi-Fi required — perfect for lecture halls with poor connectivity</li>
                <li>Faster transcription — no waiting for cloud processing</li>
                <li>Better privacy — your audio never leaves your device</li>
                <li>No data charges — especially important for international students</li>
              </ul>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Relax and Listen During Class</h3>
              <p className="text-lg text-gray-700">
                Instead of frantically writing notes, you can actually engage with the lecture. Ask questions, participate in discussions, and focus on understanding concepts. The transcription captures everything, so you can review details later.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Why Lecsy Is Built for Students */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why Lecsy Is Built for College Students
          </h2>
          <div className="grid md:grid-cols-2 gap-8">
            <div className="bg-gradient-to-br from-blue-50 to-sky-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">iPhone-Only Solution</h3>
              <p className="text-gray-700">
                Lecsy runs entirely on your iPhone. No need for laptops, external microphones, or complex setups. Just open the app and record.
              </p>
            </div>
            <div className="bg-gradient-to-br from-sky-50 to-cyan-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">100% Local Processing</h3>
              <p className="text-gray-700">
                Your audio never leaves your device. Transcription happens locally, ensuring privacy and compliance with university policies.
              </p>
            </div>
            <div className="bg-gradient-to-br from-cyan-50 to-blue-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Designed for University Lectures</h3>
              <p className="text-gray-700">
                Unlike general transcription apps, Lecsy is optimized for lecture halls, seminars, and labs. It handles fast speech, academic terminology, and varying audio quality.
              </p>
            </div>
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Free to Start</h3>
              <p className="text-gray-700">
                Unlimited recording and transcription are free forever. Pro features (AI summaries, exam prep) are just $2.99/month — affordable for students.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Comparison */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8 text-center">
            Lecsy vs Other AI Transcription Apps
          </h2>
          <ComparisonTable rows={comparisonRows} includeNotta={true} />
          <div className="mt-8 bg-blue-50 border-l-4 border-blue-600 p-6 rounded-r-lg">
            <p className="text-gray-800">
              <strong>The key difference:</strong> Lecsy works offline, processes locally, and is built specifically for college students. Other apps require internet, process in the cloud, and target general business use.
            </p>
          </div>
          <div className="mt-6 text-center">
            <Link
              href="/otter-alternative-for-lectures"
              className="text-blue-600 hover:text-blue-700 font-semibold underline"
            >
              See detailed comparison: Lecsy vs Otter vs Notta →
            </Link>
          </div>
        </div>
      </section>

      {/* How to Use */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How to Use Lecsy in Real Classes
          </h2>
          <div className="space-y-8">
            <div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Step 1: Open the App</h3>
              <p className="text-lg text-gray-700 mb-4">
                Before class starts, open Lecsy on your iPhone. Make sure you have enough storage space (each hour of recording uses about 50-100MB).
              </p>
            </div>
            <div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Step 2: Tap Record</h3>
              <p className="text-lg text-gray-700 mb-4">
                When your professor starts lecturing, tap the record button. Lecsy will continue recording even if you lock your phone or switch to other apps. Perfect for 90-minute lectures.
              </p>
            </div>
            <div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Step 3: Review on Web</h3>
              <p className="text-lg text-gray-700 mb-4">
                After class, open Lecsy on your computer or tablet. The transcript will be ready — search for keywords, copy important sections, and use AI summaries (Pro) to extract key points.
              </p>
            </div>
            <div className="bg-gray-50 p-6 rounded-xl">
              <h4 className="text-xl font-bold text-gray-900 mb-3">Real Example: History Lecture</h4>
              <p className="text-gray-700">
                In a 300-person history lecture hall, the professor speaks quickly and covers multiple topics. With Lecsy, you can:
              </p>
              <ul className="list-disc list-inside space-y-2 text-gray-700 mt-3">
                <li>Record the entire 90-minute lecture</li>
                <li>Get a full transcript within minutes (processed on your iPhone)</li>
                <li>Search for "World War II" to find all relevant sections</li>
                <li>Copy important dates and facts for your notes</li>
                <li>Use AI summary (Pro) to get key points before the exam</li>
              </ul>
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
              href="/lecture-recording-app-college"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Lecture Recording App for College</h3>
              <p className="text-sm text-gray-600">Learn how to record different types of classes effectively.</p>
            </Link>
            <Link
              href="/ai-note-taking-for-international-students"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Note Taking for International Students</h3>
              <p className="text-sm text-gray-600">Specifically designed for ESL students struggling with English lectures.</p>
            </Link>
            <Link
              href="/otter-alternative-for-lectures"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Otter Alternative for Lectures</h3>
              <p className="text-sm text-gray-600">Compare Lecsy with Otter, Notta, and other transcription apps.</p>
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
