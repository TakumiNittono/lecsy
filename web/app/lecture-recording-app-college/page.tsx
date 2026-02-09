import type { Metadata } from 'next';
import SEOPageLayout from '@/components/SEOPageLayout';
import FAQSection from '@/components/FAQSection';
import Link from 'next/link';

export const metadata: Metadata = {
  title: "Best Lecture Recording App for College – Record & Transcribe on iPhone",
  description: "Record college lectures on your iPhone with Lecsy. Works offline, transcribes with AI, and lets you review anytime. The best lecture recording app for students.",
  alternates: {
    canonical: "https://www.lecsy.app/lecture-recording-app-college",
  },
  openGraph: {
    title: "Best Lecture Recording App for College | Lecsy",
    description: "Record and transcribe college lectures on iPhone. Offline. Free.",
    url: "https://www.lecsy.app/lecture-recording-app-college",
  },
};

const faqs = [
  {
    question: "How long can I record?",
    answer: "Lecsy supports unlimited recording length. You can record entire 3-hour lectures, multiple lectures per day, and keep recordings indefinitely. Storage depends on your iPhone's available space."
  },
  {
    question: "Does it drain my battery?",
    answer: "Recording uses minimal battery — similar to playing music. Lecsy is optimized for long recording sessions. A 90-minute lecture typically uses 5-10% battery on a fully charged iPhone."
  },
  {
    question: "Can I record in airplane mode?",
    answer: "Yes! Lecsy works perfectly in airplane mode. Recording and transcription both happen offline, so you can use Lecsy even when Wi-Fi and cellular are disabled."
  },
  {
    question: "Is it legal to record lectures?",
    answer: "Generally yes, but always check your university's policy and get professor permission. Most US universities allow recording for personal study purposes. See our guide: How to Record Lectures Legally."
  },
  {
    question: "Can I share recordings with classmates?",
    answer: "Lecsy transcripts are private to your account. For sharing, you can copy text from transcripts. However, always respect your professor's recording policy and never share without permission."
  }
];

const breadcrumbs = [
  { name: "Home", url: "https://www.lecsy.app/" },
  { name: "Lecture Recording App for College", url: "https://www.lecsy.app/lecture-recording-app-college" }
];

export default function LectureRecordingAppCollegePage() {
  return (
    <SEOPageLayout breadcrumbs={breadcrumbs}>
      {/* Hero */}
      <section className="bg-gradient-to-br from-blue-50 via-white to-blue-50 py-16 lg:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl lg:text-6xl font-bold text-gray-900 mb-6 text-center">
            Lecture Recording App for College Students
          </h1>
          <p className="text-xl text-gray-600 mb-8 text-center max-w-3xl mx-auto">
            Record college lectures on your iPhone, transcribe with AI offline, and review anytime. Built specifically for students.
          </p>
        </div>
      </section>

      {/* Why Students Need */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why Students Need a Dedicated Lecture Recording App
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">Your phone's voice memo app isn't enough.</strong> Standard voice recording apps just capture audio — they don't transcribe, don't sync to the web, and don't help you study. You're left with hours of audio files you'll never review.
            </p>
            <p>
              <strong className="text-gray-900">Recording alone doesn't help you learn.</strong> Without transcription, you have to listen to entire recordings again — time-consuming and inefficient. AI transcription turns audio into searchable text you can review in minutes.
            </p>
            <p>
              <strong className="text-gray-900">Different class types need different approaches.</strong> Large lecture halls, small seminars, and lab sessions each present unique challenges. Lecsy adapts to all of them.
            </p>
          </div>
        </div>
      </section>

      {/* How Lecsy Works */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How Lecsy Records and Transcribes Your Lectures
          </h2>
          <div className="space-y-8">
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">iPhone-Only Recording</h3>
              <p className="text-lg text-gray-700 mb-4">
                Open Lecsy, tap record, and that's it. No external microphones, no complex setup. Your iPhone's built-in microphone captures clear audio even from the back of large lecture halls.
              </p>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Background Recording</h3>
              <p className="text-lg text-gray-700 mb-4">
                Lecsy continues recording even when your phone is locked or you switch to other apps. Perfect for long lectures — start recording, lock your phone, and focus on the class.
              </p>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Offline Transcription</h3>
              <p className="text-lg text-gray-700 mb-4">
                After recording, Lecsy transcribes everything on your iPhone using on-device AI. No internet required. Transcription typically takes 1-2 minutes per hour of recording.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Different Types of Classes */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Recording Different Types of Classes
          </h2>
          <div className="space-y-8">
            <div className="border-l-4 border-blue-600 pl-6">
              <h3 className="text-2xl font-bold text-gray-900 mb-3">Large Lecture Halls (300+ students)</h3>
              <p className="text-lg text-gray-700">
                In big lecture halls, sit closer to the front for better audio quality. Lecsy's microphone picks up clear speech even from mid-rows. The transcription handles academic terminology and fast-paced delivery.
              </p>
            </div>
            <div className="border-l-4 border-sky-600 pl-6">
              <h3 className="text-2xl font-bold text-gray-900 mb-3">Small Seminars (10-30 students)</h3>
              <p className="text-lg text-gray-700">
                In seminars, Lecsy captures both professor and student discussions. The transcription distinguishes between speakers, making it easy to follow conversations and Q&A sessions.
              </p>
            </div>
            <div className="border-l-4 border-cyan-600 pl-6">
              <h3 className="text-2xl font-bold text-gray-900 mb-3">Lab Sessions & Workshops</h3>
              <p className="text-lg text-gray-700">
                For hands-on labs, place your iPhone near the instructor's station. Lecsy records explanations and instructions, helping you focus on the practical work while capturing important details.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Workflow */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            From Recording to Review: The Complete Workflow
          </h2>
          <div className="bg-white p-8 rounded-xl shadow-md space-y-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-blue-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">1</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Record</h3>
                <p className="text-gray-700">Open Lecsy, tap record, and focus on understanding the lecture. Recording continues in the background.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-sky-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">2</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Transcribe</h3>
                <p className="text-gray-700">After class, Lecsy automatically transcribes on your iPhone. No internet needed — happens locally in minutes.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-cyan-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">3</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Review on Web</h3>
                <p className="text-gray-700">Open Lecsy on your computer or tablet. Search transcripts, copy important sections, and organize your notes.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-purple-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">4</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">AI Summary (Pro)</h3>
                <p className="text-gray-700">Use AI-powered summaries to extract key points, create section breakdowns, and prepare for exams.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-pink-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">5</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Exam Prep</h3>
                <p className="text-gray-700">Pro users get Exam Mode — AI generates Q&A, predicts exam topics, and helps you study efficiently.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Comparison */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Lecsy vs Voice Memos vs Zoom Recording
          </h2>
          <div className="space-y-6">
            <div className="bg-gray-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Voice Memos (iPhone)</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>✅ Records audio</li>
                <li>❌ No transcription</li>
                <li>❌ No web access</li>
                <li>❌ Hard to search</li>
              </ul>
            </div>
            <div className="bg-gray-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Zoom Recording</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>✅ Works for online classes</li>
                <li>✅ Has transcription</li>
                <li>❌ Only for Zoom meetings</li>
                <li>❌ Requires internet</li>
                <li>❌ Doesn't work for in-person lectures</li>
              </ul>
            </div>
            <div className="bg-blue-50 border-2 border-blue-600 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Lecsy</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>✅ Records audio (offline)</li>
                <li>✅ AI transcription (offline)</li>
                <li>✅ Web access for review</li>
                <li>✅ Searchable transcripts</li>
                <li>✅ Works for all class types</li>
                <li>✅ Built for students</li>
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
              href="/ai-transcription-for-students"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Transcription for Students</h3>
              <p className="text-sm text-gray-600">Learn how AI transcription helps college students understand lectures better.</p>
            </Link>
            <Link
              href="/how-to-record-lectures-legally"
              className="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">How to Record Lectures Legally</h3>
              <p className="text-sm text-gray-600">Everything you need to know about recording college lectures legally.</p>
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
