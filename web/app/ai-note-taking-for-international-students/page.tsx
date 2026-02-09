import type { Metadata } from 'next';
import SEOPageLayout from '@/components/SEOPageLayout';
import FAQSection from '@/components/FAQSection';
import ComparisonTable from '@/components/ComparisonTable';
import Link from 'next/link';

export const metadata: Metadata = {
  title: "AI Note Taking for International Students – Never Miss a Lecture Again",
  description: "International and ESL students: stop struggling with fast-paced English lectures. Lecsy records, transcribes, and summarizes your lectures with AI. Read at your own pace.",
  alternates: {
    canonical: "https://www.lecsy.app/ai-note-taking-for-international-students",
  },
  openGraph: {
    title: "AI Note Taking for International Students | Lecsy",
    description: "For ESL students who struggle with fast-paced English lectures. Record, transcribe, review.",
    url: "https://www.lecsy.app/ai-note-taking-for-international-students",
  },
};

const faqs = [
  {
    question: "Does it understand accented English?",
    answer: "Yes! Lecsy's AI transcription is trained on diverse English accents and dialects. It handles various accents well, including British, Australian, Indian, and non-native English speakers. However, very heavy accents or unclear speech may require manual review."
  },
  {
    question: "Can I review lectures in my native language?",
    answer: "Currently, Lecsy transcribes in English (or Japanese). The transcript is in English, but you can use translation tools on the web version to translate sections to your native language for better understanding."
  },
  {
    question: "Is it free for students?",
    answer: "Yes! Lecsy is free forever for basic features — unlimited recording and transcription. Pro features (AI summaries, exam prep) are $2.99/month, which is affordable for students compared to other apps that charge $13-17/month."
  },
  {
    question: "How is this different from Otter.ai?",
    answer: "Lecsy works completely offline, processes locally on your iPhone (better privacy), and is built specifically for students. Otter requires internet, processes in the cloud, and targets business users. Lecsy is also much more affordable — free vs Otter's $16.99/month for similar features."
  },
  {
    question: "What if I don't understand some words in the transcript?",
    answer: "That's exactly why Lecsy is helpful! You can read the transcript at your own pace, look up unfamiliar words, and review difficult sections multiple times. This is much easier than trying to catch everything during a fast-paced live lecture."
  }
];

const comparisonRows = [
  {
    feature: "Price",
    lecsy: "Free (Pro $2.99/mo)",
    otter: "Free limited, $16.99/mo"
  },
  {
    feature: "Offline Recording",
    lecsy: true,
    otter: false
  },
  {
    feature: "Offline Transcription",
    lecsy: true,
    otter: false
  },
  {
    feature: "Privacy (Local Processing)",
    lecsy: true,
    otter: false
  },
  {
    feature: "Built for Students",
    lecsy: true,
    otter: false
  },
  {
    feature: "Works Without Internet",
    lecsy: true,
    otter: false
  }
];

const breadcrumbs = [
  { name: "Home", url: "https://www.lecsy.app/" },
  { name: "AI Note Taking for International Students", url: "https://www.lecsy.app/ai-note-taking-for-international-students" }
];

export default function AINoteTakingForInternationalStudentsPage() {
  return (
    <SEOPageLayout breadcrumbs={breadcrumbs}>
      {/* Hero */}
      <section className="bg-gradient-to-br from-blue-50 via-white to-blue-50 py-16 lg:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl lg:text-6xl font-bold text-gray-900 mb-6 text-center">
            AI Note Taking App for International Students
          </h1>
          <p className="text-xl text-gray-600 mb-8 text-center max-w-3xl mx-auto">
            Stop struggling with fast-paced English lectures. Record, transcribe, and review at your own pace. Built specifically for ESL and international students.
          </p>
        </div>
      </section>

      {/* Why International Students Struggle */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why International Students Struggle With English Lectures
          </h2>
          <div className="space-y-6 text-lg text-gray-700">
            <p>
              <strong className="text-gray-900">The listening speed gap is real.</strong> Native English speakers process speech at 150-200 words per minute. For ESL students, processing speed is slower, especially when dealing with academic vocabulary and complex concepts. Fast-speaking professors become overwhelming.
            </p>
            <p>
              <strong className="text-gray-900">Accents and slang add complexity.</strong> Different professors have different accents — British, Australian, regional American. Add academic jargon and casual expressions, and understanding becomes even harder.
            </p>
            <p>
              <strong className="text-gray-900">Taking notes while listening is double the challenge.</strong> You're trying to understand English AND write notes at the same time. This cognitive load means you miss important information. Many international students report understanding only 50-70% of lecture content.
            </p>
            <p>
              <strong className="text-gray-900">"I struggled with understanding fast professors."</strong> This is a common experience. In a 300-person lecture hall, asking professors to slow down isn't always possible. You need a solution that works for you.
            </p>
            <div className="bg-blue-50 border-l-4 border-blue-600 p-6 rounded-r-lg mt-8">
              <p className="text-gray-800 italic">
                "As a Japanese student studying in the US, I used to miss half of what my professor said in History 101. Even when I understood the words, I couldn't process the concepts fast enough. Lecsy changed everything — now I can focus on understanding during class and review the full transcript later at my own pace."
              </p>
              <p className="text-sm text-gray-600 mt-2">— International student, UC Berkeley</p>
            </div>
          </div>
        </div>
      </section>

      {/* How AI Note Taking Transforms */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How AI Note Taking Transforms the Lecture Experience
          </h2>
          <div className="space-y-8">
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Record Everything, Review at Your Pace</h3>
              <p className="text-lg text-gray-700 mb-4">
                Instead of trying to catch every word during class, you can relax and focus on understanding concepts. Record the entire lecture, then review the transcript later when you have time to:
              </p>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Read at your own comfortable speed</li>
                <li>Look up unfamiliar words and phrases</li>
                <li>Reread difficult sections multiple times</li>
                <li>Take notes from the transcript, not during the lecture</li>
              </ul>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Audio + Text = Better Understanding</h3>
              <p className="text-lg text-gray-700 mb-4">
                Lecsy gives you both the audio recording and the text transcript. This combination is powerful for language learning:
              </p>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Read the transcript while listening to improve pronunciation recognition</li>
                <li>See how words are spelled while hearing them spoken</li>
                <li>Understand context better by reading and listening simultaneously</li>
                <li>Build vocabulary by seeing academic terms in context</li>
              </ul>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-md">
              <h3 className="text-2xl font-bold text-gray-900 mb-4">AI Summary Helps Extract Key Points</h3>
              <p className="text-lg text-gray-700">
                Pro users get AI-powered summaries that extract main concepts, key points, and important details. This helps you focus on what matters most, especially when dealing with long, complex lectures in a second language.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Why Lecsy for International Students */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Why Lecsy Is the Best Choice for International Students
          </h2>
          <div className="grid md:grid-cols-2 gap-8">
            <div className="bg-gradient-to-br from-blue-50 to-sky-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Offline = No SIM Card Issues</h3>
              <p className="text-gray-700">
                Many international students use local SIM cards or limited data plans. Lecsy works completely offline — no internet needed for recording or transcription. Perfect for students with budget constraints.
              </p>
            </div>
            <div className="bg-gradient-to-br from-sky-50 to-cyan-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Privacy: Data Stays Local</h3>
              <p className="text-gray-700">
                Your audio never leaves your iPhone. All processing happens locally, so you don't have to worry about your recordings being stored on foreign servers or privacy concerns.
              </p>
            </div>
            <div className="bg-gradient-to-br from-cyan-50 to-blue-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Simple UI, No Language Barrier</h3>
              <p className="text-gray-700">
                Lecsy's interface is clean and intuitive. No complex settings or confusing options. Just record, transcribe, and review — simple enough for anyone, regardless of English proficiency.
              </p>
            </div>
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Free to Start</h3>
              <p className="text-gray-700">
                Unlimited recording and transcription are free forever. Pro features are just $2.99/month — much more affordable than Otter ($16.99/month) or Notta ($13.99/month).
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Lecsy vs Otter */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8 text-center">
            Lecsy vs Otter for International Students
          </h2>
          <ComparisonTable rows={comparisonRows} includeNotta={false} />
          <div className="mt-8 space-y-4">
            <div className="bg-white p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Otter: Internet Required, Privacy Concerns, Expensive</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Requires internet connection — problematic for students with limited data</li>
                <li>Processes audio in the cloud — privacy concerns for international students</li>
                <li>$16.99/month for unlimited transcription — expensive for students</li>
                <li>Designed for business meetings, not academic lectures</li>
              </ul>
            </div>
            <div className="bg-blue-50 border-2 border-blue-600 p-6 rounded-xl">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Lecsy: Offline, Private, Affordable</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Works completely offline — no data charges</li>
                <li>Local processing — your audio never leaves your device</li>
                <li>Free forever for basic features, $2.99/month for Pro</li>
                <li>Built specifically for college students and academic lectures</li>
              </ul>
            </div>
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

      {/* Real Student Stories */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            Real Student Stories
          </h2>
          <div className="space-y-6">
            <div className="bg-gray-50 p-6 rounded-xl border-l-4 border-blue-600">
              <p className="text-gray-800 italic mb-3">
                "As a Japanese student studying in the US, I used to miss half of what my professor said in History 101. Even when I understood the words, I couldn't process the concepts fast enough. Lecsy changed everything — now I can focus on understanding during class and review the full transcript later at my own pace."
              </p>
              <p className="text-sm text-gray-600">— International student, UC Berkeley</p>
            </div>
            <div className="bg-gray-50 p-6 rounded-xl border-l-4 border-sky-600">
              <p className="text-gray-800 italic mb-3">
                "I used to struggle with fast-speaking professors in my Computer Science classes. The technical terms were hard enough, but combined with fast speech, I was lost. With Lecsy, I record everything, then review the transcript with a dictionary open. My grades improved significantly."
              </p>
              <p className="text-sm text-gray-600">— ESL student, MIT</p>
            </div>
            <div className="bg-gray-50 p-6 rounded-xl border-l-4 border-cyan-600">
              <p className="text-gray-800 italic mb-3">
                "The best part about Lecsy is that it works offline. I don't have an expensive data plan, so I can't use apps that require internet. Lecsy records and transcribes everything on my phone — perfect for my budget."
              </p>
              <p className="text-sm text-gray-600">— International student, NYU</p>
            </div>
          </div>
        </div>
      </section>

      {/* How to Get Started */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl lg:text-4xl font-bold text-gray-900 mb-8">
            How to Get Started
          </h2>
          <div className="bg-white p-8 rounded-xl shadow-md space-y-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-blue-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">1</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Download Lecsy</h3>
                <p className="text-gray-700">Get Lecsy from the App Store (free). No account required to start recording.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-sky-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">2</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Record Your First Lecture</h3>
                <p className="text-gray-700">Open Lecsy, tap record, and let it capture everything. Focus on listening and understanding.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-cyan-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">3</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Review the Transcript</h3>
                <p className="text-gray-700">After class, open Lecsy on your computer. Read the transcript at your own pace, look up words, and take notes.</p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-purple-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">4</div>
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Upgrade to Pro (Optional)</h3>
                <p className="text-gray-700">Get AI summaries, exam prep mode, and key points extraction for just $2.99/month.</p>
              </div>
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
              href="/ai-transcription-for-students"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">AI Transcription for Students</h3>
              <p className="text-sm text-gray-600">Learn how AI transcription helps college students understand lectures better.</p>
            </Link>
            <Link
              href="/otter-alternative-for-lectures"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Otter Alternative for Lectures</h3>
              <p className="text-sm text-gray-600">Compare Lecsy with Otter, Notta, and other transcription apps.</p>
            </Link>
            <Link
              href="/lecture-recording-app-college"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
            >
              <h3 className="font-semibold text-gray-900 mb-2">Lecture Recording App for College</h3>
              <p className="text-sm text-gray-600">Learn how to record different types of classes effectively.</p>
            </Link>
            <Link
              href="/how-to-record-lectures-legally"
              className="block p-4 bg-gray-50 rounded-lg shadow hover:shadow-md transition-shadow border border-gray-200"
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
