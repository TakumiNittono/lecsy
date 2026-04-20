import Link from "next/link";
import type { Metadata } from "next";
import { Space_Grotesk } from "next/font/google";
import { APP_STORE_URL } from "@/lib/constants";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-display",
});

export const metadata: Metadata = {
  title: "Lecsy | Free Lecture Recording & AI Notes App for Students",
  description:
    "Record lectures on iPhone, get real-time bilingual captions via Deepgram, AI summaries & study guides in 20+ languages. Built for international students. Free plan available. Lecsy never stores your audio.",
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
};

/* ─── Icons ─── */

function CheckIcon({ className = "w-5 h-5 text-blue-600" }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
    </svg>
  );
}

function XIcon() {
  return (
    <svg className="w-5 h-5 text-red-400/70" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
    </svg>
  );
}

function AppleIcon({ className = "w-6 h-6" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 22 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.09997 22C7.78997 22.05 6.79997 20.68 5.95997 19.47C4.24997 17 2.93997 12.45 4.69997 9.39C5.56997 7.87 7.12997 6.91 8.81997 6.88C10.1 6.86 11.32 7.75 12.11 7.75C12.89 7.75 14.37 6.68 15.92 6.84C16.57 6.87 18.39 7.1 19.56 8.82C19.47 8.88 17.39 10.1 17.41 12.63C17.44 15.65 20.06 16.66 20.09 16.67C20.06 16.74 19.67 18.11 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
    </svg>
  );
}

/* ─── Waveform ─── */

function Waveform() {
  return (
    <div className="flex items-end gap-[3px] h-8" aria-hidden="true">
      {[40, 70, 55, 85, 45, 90, 60, 75, 50, 80, 35, 65, 95, 55, 70, 40, 85, 50, 75, 60].map(
        (h, i) => (
          <div
            key={i}
            className="w-[3px] rounded-full bg-blue-400"
            style={{ height: `${h}%` }}
          />
        )
      )}
    </div>
  );
}

/* ─── Page ─── */

export default function Home() {
  return (
    <main className={`${spaceGrotesk.variable} min-h-screen bg-white`}>
      {/* ── JSON-LD ── */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "FAQPage",
            mainEntity: [
              { "@type": "Question", name: "Is my data safe with Lecsy?", acceptedAnswer: { "@type": "Answer", text: "Audio is streamed to Deepgram for real-time transcription over an encrypted connection. Deepgram automatically deletes processed audio within 30 days. Lecsy itself never stores your audio. Transcript text syncs to our cloud only when you sign in. AI features send transcript text only (never audio) to OpenAI." } },
              { "@type": "Question", name: "Do I need internet to record and transcribe?", acceptedAnswer: { "@type": "Answer", text: "Real-time bilingual captions require internet because audio is streamed to Deepgram for transcription. If you're offline you can still record locally and transcribe later when you reconnect." } },
              { "@type": "Question", name: "What languages does Lecsy support?", acceptedAnswer: { "@type": "Answer", text: "Lecsy supports 12 languages for transcription: English, Japanese, Spanish, French, German, Chinese, Korean, and more. AI summaries can be generated in a different language than the recording." } },
              { "@type": "Question", name: "How does Lecsy compare to Otter.ai?", acceptedAnswer: { "@type": "Answer", text: "Lecsy is built specifically for international students with real-time bilingual captions. Both Lecsy and Otter use cloud transcription for the paid tier, but Lecsy never stores your audio (Deepgram auto-deletes within 30 days). Lecsy Pro is $12.99/month vs Otter's $16.99/month, and Lecsy has a permanent Free plan." } },
              { "@type": "Question", name: "Is it legal to record lectures?", acceptedAnswer: { "@type": "Answer", text: "In most universities, recording lectures for personal study is permitted. Many schools encourage it as an accessibility accommodation. Check your university's policy." } },
              { "@type": "Question", name: "How accurate is the transcription?", acceptedAnswer: { "@type": "Answer", text: "Lecsy uses Deepgram Nova-3 multilingual model. Accuracy is typically 95%+ for clear English lecture audio and 90%+ for non-native speakers." } },
              { "@type": "Question", name: "Is Lecsy really free?", acceptedAnswer: { "@type": "Answer", text: "The Free plan is permanently free: on-device recording, AI Study Guide (3 per month), and transcript sync. Upgrade to Pro ($12.99/month) or Student ($7.99/month) for real-time bilingual captions and unlimited AI features." } },
              { "@type": "Question", name: "What about AI summaries — does my data go to a server?", acceptedAnswer: { "@type": "Answer", text: "When you tap AI Summary or Exam Mode, only the transcript text (never audio) is sent to OpenAI's GPT-4o-mini to generate the summary. OpenAI does not use API content to train its models. Audio always stays on your iPhone." } },
            ],
          }),
        }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            name: "Lecsy",
            operatingSystem: "iOS 17.6+",
            applicationCategory: "EducationApplication",
            offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
            description: "Free lecture recording and AI study app. Record unlimited lectures, transcribe offline, get AI summaries and exam prep in 12 languages.",
            url: "https://www.lecsy.app/",
            downloadUrl: APP_STORE_URL,
            author: { "@type": "Person", name: "Takumi Nittono" },
          }),
        }}
      />

      {/* ━━━ HEADER ━━━ */}
      <header className="fixed top-0 w-full z-50 border-b border-gray-100 bg-white/80 backdrop-blur-xl">
        <div className="max-w-6xl mx-auto px-5 h-14 flex items-center justify-between">
          <Link
            href="/"
            className="font-[family-name:var(--font-display)] text-xl font-bold tracking-tight text-blue-600"
          >
            lecsy
          </Link>

          <nav className="hidden md:flex items-center gap-8 text-[13px] text-gray-500">
            <Link href="#features" className="hover:text-gray-900 transition-colors">Features</Link>
            <Link href="#compare" className="hover:text-gray-900 transition-colors">Compare</Link>
            <Link href="#pricing" className="hover:text-gray-900 transition-colors">Pricing</Link>
            <Link href="#faq" className="hover:text-gray-900 transition-colors">FAQ</Link>
          </nav>

          <div className="flex items-center gap-3">
            <Link
              href="/login"
              className="text-[13px] text-gray-500 hover:text-gray-900 transition-colors hidden sm:block"
            >
              Log in
            </Link>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="h-8 px-4 flex items-center gap-2 rounded-full bg-blue-600 text-white text-[13px] font-semibold hover:bg-blue-700 transition-colors"
            >
              <AppleIcon className="w-4 h-4" />
              Download
            </a>
          </div>
        </div>
      </header>

      {/* ━━━ HERO ━━━ */}
      {/* ━━━ COMING SOON BIG ANNOUNCEMENT ━━━ */}
      <section className="relative pt-24 pb-6 overflow-hidden bg-gradient-to-br from-indigo-600 via-blue-600 to-blue-700">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(255,255,255,0.15),transparent_60%)]" />
        <div className="relative max-w-6xl mx-auto px-5 text-center">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/15 border border-white/30 backdrop-blur-sm mb-4">
            <span className="w-2 h-2 rounded-full bg-yellow-300 animate-pulse" />
            <span className="text-xs font-bold text-white tracking-widest uppercase">
              Coming Soon · Private Beta
            </span>
          </div>
          <h2 className="font-[family-name:var(--font-display)] text-3xl md:text-5xl lg:text-6xl font-extrabold text-white tracking-tight mb-4">
            Real-time bilingual captions,
            <br className="hidden md:block" />
            <span className="text-yellow-200"> powered by Deepgram.</span>
          </h2>
          <p className="text-lg lg:text-xl text-blue-100 max-w-2xl mx-auto mb-6">
            See the lecture in English AND your native language —
            live, in class, word-by-word. Launching for international students this summer.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <a
              href="mailto:support@lecsy.app?subject=Lecsy%20Beta%20Waitlist"
              className="inline-flex items-center gap-2 h-12 px-6 rounded-xl bg-white text-blue-700 font-bold text-sm hover:bg-blue-50 transition-all shadow-lg"
            >
              Join the waitlist
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
              </svg>
            </a>
            <span className="text-xs text-blue-200">
              Current Lecsy users stay free with on-device WhisperKit.
            </span>
          </div>
        </div>
      </section>

      <section className="relative pt-20 pb-20 lg:pt-28 lg:pb-32 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-blue-50/80 via-white to-white pointer-events-none" />
        <div className="absolute top-20 left-1/2 -translate-x-1/2 w-[900px] h-[600px] bg-blue-400/[0.08] rounded-full blur-[120px] pointer-events-none" />

        <div className="relative max-w-6xl mx-auto px-5">
          <div className="max-w-3xl animate-fade-in-up">
            <div className="inline-flex items-center gap-2 mb-8 px-3 py-1.5 rounded-full border border-blue-200 bg-blue-50">
              <span className="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse" />
              <span className="text-xs font-medium text-blue-600 tracking-wide">
                Available now · Free · On-device
              </span>
            </div>

            <h1 className="font-[family-name:var(--font-display)] text-[clamp(2.5rem,7vw,5.5rem)] font-bold leading-[0.95] tracking-tight text-gray-900 mb-6">
              Your lectures,
              <br />
              <span className="text-blue-600">transcribed.</span>
            </h1>

            <p className="text-lg lg:text-xl text-gray-500 leading-relaxed max-w-xl mb-10">
              Record on iPhone. Transcribe offline. Get AI summaries and exam
              prep in 12 languages. <span className="text-gray-900 font-semibold">$0.</span>
            </p>

            <div className="flex flex-col sm:flex-row gap-3">
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="group inline-flex items-center justify-center gap-3 h-12 px-6 rounded-xl bg-blue-600 text-white font-semibold text-sm hover:bg-blue-700 transition-all shadow-lg shadow-blue-600/20"
              >
                <AppleIcon className="w-5 h-5" />
                Download for iPhone
                <svg className="w-4 h-4 opacity-60 group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </a>
              <Link
                href="/login"
                className="inline-flex items-center justify-center h-12 px-6 rounded-xl border border-gray-200 text-gray-700 font-medium text-sm hover:border-gray-300 hover:bg-gray-50 transition-all"
              >
                Open Web App
              </Link>
            </div>

            <p className="mt-6 text-sm text-gray-400">
              Save $204/year compared to Otter.ai
            </p>
          </div>

          {/* Right side - floating card */}
          <div className="hidden lg:block absolute right-0 top-1/2 -translate-y-1/2 w-72">
            <div className="bg-white shadow-2xl shadow-blue-900/[0.08] border border-gray-100 rounded-2xl p-6 space-y-5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wider">Recording</span>
                <span className="flex items-center gap-1.5 text-xs text-blue-600 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse" />
                  Live
                </span>
              </div>
              <Waveform />
              <div className="space-y-2">
                <div className="h-2 bg-gray-100 rounded-full w-full" />
                <div className="h-2 bg-gray-100 rounded-full w-4/5" />
                <div className="h-2 bg-gray-100 rounded-full w-3/5" />
                <div className="h-2 bg-blue-100 rounded-full w-2/3" />
              </div>
              <div className="flex items-center gap-2 text-xs text-gray-400">
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                On-device &middot; Never uploaded
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ STATS BAR ━━━ */}
      <section className="border-y border-gray-100 bg-gray-50/50">
        <div className="max-w-6xl mx-auto px-5 py-10 grid grid-cols-2 md:grid-cols-4 gap-8">
          {[
            { value: "$0", label: "Free plan, forever", accent: true },
            { value: "\u221E", label: "Recording minutes" },
            { value: "12", label: "Languages supported" },
            { value: "0", label: "Audio on our servers", suffix: "bytes" },
          ].map((stat) => (
            <div key={stat.label} className="text-center">
              <div
                className={`font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold tracking-tight ${
                  stat.accent ? "text-blue-600" : "text-gray-900"
                }`}
              >
                {stat.value}
                {stat.suffix && (
                  <span className="text-base font-normal text-gray-400 ml-1">{stat.suffix}</span>
                )}
              </div>
              <div className="text-sm text-gray-500 mt-1">{stat.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ━━━ FOR INTERNATIONAL STUDENTS ━━━ */}
      <section id="international-students" className="py-20 lg:py-28 bg-gradient-to-br from-blue-50 via-white to-indigo-50">
        <div className="max-w-5xl mx-auto px-5">
          <div className="text-center mb-12">
            <span className="inline-block px-3 py-1 mb-4 text-xs font-semibold uppercase tracking-wider text-blue-700 bg-blue-100 rounded-full">
              For international students
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-bold text-gray-900 tracking-tight mb-4">
              Lectures in English. <br className="hidden md:inline" />Notes in your language.
            </h2>
            <p className="text-lg text-gray-600 max-w-2xl mx-auto">
              You passed TOEFL. You still struggle to follow a fast-talking professor. Lecsy records the lecture, transcribes it on your iPhone, and gives you an AI summary in Japanese, Korean, Chinese, Spanish, French, German, or English — side-by-side with the original.
            </p>
          </div>

          {/* Bilingual notes mockup */}
          <div className="grid md:grid-cols-2 gap-6 max-w-3xl mx-auto mb-12">
            <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-200">
              <div className="text-xs font-semibold uppercase tracking-wider text-blue-600 mb-3">English Transcript</div>
              <p className="text-sm text-gray-800 leading-relaxed mb-4">
                This lecture covered the mechanism of cell division and how it functions in the development of multicellular organisms, with particular focus on the difference between mitosis and meiosis.
              </p>
              <div className="text-xs font-semibold text-gray-500 mb-2">Key Points</div>
              <ul className="space-y-1 text-sm text-gray-700">
                <li>• Mitosis = two daughter cells with identical DNA</li>
                <li>• Meiosis = gamete formation, chromosome halving</li>
                <li>• Checkpoints ensure division quality</li>
              </ul>
            </div>
            <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-200">
              <div className="text-xs font-semibold uppercase tracking-wider text-blue-600 mb-3">Resumen en Español</div>
              <p className="text-sm text-gray-800 leading-relaxed mb-4">
                Esta clase explicó el mecanismo de la división celular y cómo funciona en el desarrollo de organismos multicelulares, con especial atención a la diferencia entre la mitosis y la meiosis.
              </p>
              <div className="text-xs font-semibold text-gray-500 mb-2">Puntos clave</div>
              <ul className="space-y-1 text-sm text-gray-700">
                <li>• Mitosis = dos células hijas con ADN idéntico</li>
                <li>• Meiosis = formación de gametos, reducción cromosómica</li>
                <li>• Los puntos de control aseguran la calidad</li>
              </ul>
            </div>
          </div>

          {/* Why us */}
          <div className="grid md:grid-cols-3 gap-6 mb-12">
            <div className="text-center">
              <div className="w-12 h-12 mx-auto mb-3 bg-blue-100 rounded-xl flex items-center justify-center">
                <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" /></svg>
              </div>
              <h3 className="font-bold text-gray-900 mb-1">Built for iPhone</h3>
              <p className="text-sm text-gray-600">Native iOS recording. No browser, no extension, no laptop needed.</p>
            </div>
            <div className="text-center">
              <div className="w-12 h-12 mx-auto mb-3 bg-blue-100 rounded-xl flex items-center justify-center">
                <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" /></svg>
              </div>
              <h3 className="font-bold text-gray-900 mb-1">Lecsy never stores your audio</h3>
              <p className="text-sm text-gray-600">Your .m4a file stays on your iPhone. Not in our cloud, not anywhere else. Ever.</p>
            </div>
            <div className="text-center">
              <div className="w-12 h-12 mx-auto mb-3 bg-blue-100 rounded-xl flex items-center justify-center">
                <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" /></svg>
              </div>
              <h3 className="font-bold text-gray-900 mb-1">Never trained on your data</h3>
              <p className="text-sm text-gray-600">Not by us, not by OpenAI. Your lectures are private. Period.</p>
            </div>
          </div>

        </div>
      </section>

      {/* ━━━ COMPARISON ━━━ */}
      <section id="compare" className="py-20 lg:py-28 bg-white">
        <div className="max-w-4xl mx-auto px-5">
          <div className="mb-12">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-gray-900 tracking-tight mb-3">
              Why students switch
            </h2>
            <p className="text-gray-500 text-lg">
              Otter charges $17/mo and needs WiFi. You deserve better.
            </p>
          </div>

          <div className="rounded-2xl border border-gray-200 overflow-hidden bg-white shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/50">
                    <th className="text-left p-4 text-gray-400 font-medium w-2/5" />
                    <th className="p-4 text-center">
                      <span className="font-[family-name:var(--font-display)] text-lg font-bold text-blue-600">
                        Lecsy
                      </span>
                    </th>
                    <th className="p-4 text-center">
                      <span className="text-gray-400 font-medium">Otter.ai</span>
                    </th>
                    <th className="p-4 text-center">
                      <span className="text-gray-400 font-medium">Notta</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {[
                    { feature: "Price", lecsy: "FREE", otter: "$16.99/mo", notta: "$13.99/mo", highlight: true },
                    { feature: "Monthly minutes", lecsy: "Unlimited", otter: "300 min", notta: "120 min" },
                    { feature: "Works offline", lecsy: true, otter: false, notta: false },
                    { feature: "On-device transcription", lecsy: true, otter: false, notta: false },
                    { feature: "Audio stays on device", lecsy: true, otter: false, notta: false },
                    { feature: "AI summaries", lecsy: true, otter: true, notta: true },
                    { feature: "Exam prep mode", lecsy: true, otter: false, notta: false },
                    { feature: "Annual cost", lecsy: "$0", otter: "$203.88", notta: "$167.88", strikeOthers: true },
                  ].map((row, i) => (
                    <tr key={row.feature} className={`border-b border-gray-50 ${i % 2 === 0 ? "bg-blue-50/20" : ""}`}>
                      <td className="p-4 font-medium text-gray-600">{row.feature}</td>
                      <td className="p-4 text-center">
                        {typeof row.lecsy === "boolean" ? (
                          row.lecsy ? <CheckIcon /> : <XIcon />
                        ) : (
                          <span className={`font-bold ${row.highlight ? "text-blue-600 text-lg" : "text-gray-900"}`}>
                            {row.lecsy}
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-center">
                        {typeof row.otter === "boolean" ? (
                          row.otter ? <CheckIcon className="w-5 h-5 text-gray-400" /> : <XIcon />
                        ) : (
                          <span className={row.strikeOthers ? "line-through text-gray-300" : "text-gray-500"}>
                            {row.otter}
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-center">
                        {typeof row.notta === "boolean" ? (
                          row.notta ? <CheckIcon className="w-5 h-5 text-gray-400" /> : <XIcon />
                        ) : (
                          <span className={row.strikeOthers ? "line-through text-gray-300" : "text-gray-500"}>
                            {row.notta}
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <p className="mt-6 inline-flex items-center gap-2 px-4 py-2 rounded-full border border-blue-200 bg-blue-50 text-sm text-blue-600 font-medium">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Save up to $204/year with Lecsy
          </p>
        </div>
      </section>

      {/* ━━━ HOW IT WORKS ━━━ */}
      <section id="how-it-works" className="bg-gray-50 py-20 lg:py-28">
        <div className="max-w-5xl mx-auto px-5">
          <div className="mb-16">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-gray-900 tracking-tight mb-3">
              Three taps to better grades
            </h2>
            <p className="text-gray-500 text-lg">No account required. Just open and record.</p>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              {
                step: "01",
                title: "Record",
                desc: "Open the app. Tap record. Works in the background, screen locked, all day long.",
                icon: "M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z",
              },
              {
                step: "02",
                title: "Transcribe",
                desc: "Deepgram Nova-3 transcribes lectures in real time over an encrypted connection. Deepgram auto-deletes audio in 30 days. 20+ languages.",
                icon: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
              },
              {
                step: "03",
                title: "Study",
                desc: "Get AI summaries and exam questions. Read in your language. Review on your phone or laptop.",
                icon: "M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z",
              },
            ].map((item) => (
              <div
                key={item.step}
                className="group relative p-8 rounded-2xl border border-gray-200 bg-white hover-lift"
              >
                <span className="font-[family-name:var(--font-display)] text-5xl font-bold text-gray-100 group-hover:text-blue-100 transition-colors absolute top-6 right-6">
                  {item.step}
                </span>
                <div className="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center mb-6">
                  <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d={item.icon} />
                  </svg>
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-xl font-bold text-gray-900 mb-2">
                  {item.title}
                </h3>
                <p className="text-gray-500 text-sm leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ FEATURES BENTO ━━━ */}
      <section id="features" className="bg-white py-20 lg:py-28">
        <div className="max-w-5xl mx-auto px-5">
          <div className="mb-16">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-gray-900 tracking-tight mb-3">
              Built for how students actually study
            </h2>
          </div>

          <div className="grid md:grid-cols-6 gap-4">
            {/* Large card - Privacy */}
            <div className="md:col-span-4 p-8 rounded-2xl bg-blue-600 text-white relative overflow-hidden group">
              <div className="absolute top-0 right-0 w-64 h-64 bg-blue-400/30 rounded-full blur-[80px] pointer-events-none" />
              <div className="relative">
                <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center mb-5">
                  <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-xl font-bold mb-2">
                  Audio stays on your iPhone
                </h3>
                <p className="text-blue-100 text-sm leading-relaxed max-w-sm">
                  Lecsy never stores your audio. Live transcription is performed by Deepgram and processed audio is auto-deleted within 30 days. Your local .m4a backup file stays on your device. No ads, no trackers, no IDFA.
                </p>
              </div>
            </div>

            {/* Small card - AI Summaries */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-gray-200 bg-gray-50 flex flex-col justify-between">
              <svg className="w-5 h-5 text-blue-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              <div>
                <h3 className="font-[family-name:var(--font-display)] font-bold text-gray-900 mb-1">
                  AI Summaries
                </h3>
                <p className="text-gray-500 text-xs leading-relaxed">
                  Key points, section outlines, and definitions — generated from your transcript text via GPT-4o-mini.
                </p>
              </div>
            </div>

            {/* Small card - Exam Mode */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-gray-200 bg-gray-50 flex flex-col justify-between">
              <svg className="w-5 h-5 text-blue-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
              </svg>
              <div>
                <h3 className="font-[family-name:var(--font-display)] font-bold text-gray-900 mb-1">
                  Exam Mode
                </h3>
                <p className="text-gray-500 text-xs leading-relaxed">
                  AI generates likely test questions with model answers from your lecture. Ace your exams.
                </p>
              </div>
            </div>

            {/* Small card - Offline */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-gray-200 bg-gray-50 flex flex-col justify-between">
              <svg className="w-5 h-5 text-blue-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M18.364 5.636a9 9 0 11-12.728 0M12 3v9" />
              </svg>
              <div>
                <h3 className="font-[family-name:var(--font-display)] font-bold text-gray-900 mb-1">
                  Works Offline
                </h3>
                <p className="text-gray-500 text-xs leading-relaxed">
                  Recording and transcription work without internet. Perfect for lecture halls with zero Wi-Fi.
                </p>
              </div>
            </div>

            {/* Medium card - 12 Languages */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-gray-200 bg-gray-50">
              <svg className="w-5 h-5 text-blue-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
              </svg>
              <h3 className="font-[family-name:var(--font-display)] font-bold text-gray-900 mb-1">
                12 Languages
              </h3>
              <p className="text-gray-500 text-xs leading-relaxed">
                English, Japanese, Chinese, Korean, Spanish, French, German, and more. Record in one language, read the summary in another.
              </p>
            </div>

            {/* Medium card - Synced Playback */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-gray-200 bg-gray-50">
              <svg className="w-5 h-5 text-blue-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 className="font-[family-name:var(--font-display)] font-bold text-gray-900 mb-1">
                Synced Playback
              </h3>
              <p className="text-gray-500 text-xs leading-relaxed">
                Audio and text move together. Tap any sentence to jump. 0.75x to 2x speed.
              </p>
            </div>

            {/* Large card - Cross device */}
            <div className="md:col-span-4 p-8 rounded-2xl border border-gray-200 bg-gray-50 relative overflow-hidden">
              <svg className="w-5 h-5 text-blue-600 mb-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <h3 className="font-[family-name:var(--font-display)] text-xl font-bold text-gray-900 mb-2">
                Read on Any Device
              </h3>
              <p className="text-gray-500 text-sm leading-relaxed max-w-md">
                Sync transcripts to the web with one tap. Review on your laptop before exams.
                Search across your entire lecture library at lecsy.app.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ DATA TRANSPARENCY ━━━ */}
      <section className="bg-gray-50 py-20 lg:py-28">
        <div className="max-w-4xl mx-auto px-5">
          <div className="mb-12">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-gray-900 tracking-tight mb-3">
              What actually happens to your data
            </h2>
            <p className="text-gray-500 text-lg">No fine print. Here&apos;s the honest version.</p>
          </div>

          <div className="space-y-4">
            {[
              {
                icon: "M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z",
                title: "Audio (.m4a)",
                status: "NEVER leaves your iPhone",
                statusColor: "text-green-600",
                desc: "There is no code path in Lecsy that uploads your audio file. Not to our servers, not to OpenAI, not anywhere.",
              },
              {
                icon: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
                title: "Transcript text",
                status: "Synced if signed in (can turn off)",
                statusColor: "text-amber-600",
                desc: "When you're signed in, transcript text backs up to our server (Supabase) so you can recover it if you lose your phone. Turn off anytime: Settings \u2192 Privacy \u2192 Cloud Sync.",
              },
              {
                icon: "M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z",
                title: "AI Summary & Exam Mode",
                status: "Text sent to OpenAI when you tap the button",
                statusColor: "text-amber-600",
                desc: "Only the transcript text (never audio) goes to OpenAI\u2019s GPT-4o-mini to generate your summary. OpenAI does not use API content to train its models.",
              },
              {
                icon: "M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636",
                title: "Ads, trackers, IDFA",
                status: "None",
                statusColor: "text-green-600",
                desc: "No ad SDKs. No third-party analytics. No IDFA tracking. We don\u2019t sell your data.",
              },
            ].map((item) => (
              <div key={item.title} className="bg-white rounded-2xl p-6 border border-gray-200 flex gap-4">
                <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center flex-shrink-0">
                  <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d={item.icon} />
                  </svg>
                </div>
                <div>
                  <div className="flex items-baseline gap-2 mb-1">
                    <h3 className="font-bold text-gray-900">{item.title}</h3>
                    <span className={`text-xs font-semibold ${item.statusColor}`}>{item.status}</span>
                  </div>
                  <p className="text-sm text-gray-500 leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ PRICING ━━━ */}
      <section id="pricing" className="bg-white py-20 lg:py-28">
        <div className="max-w-3xl mx-auto px-5">
          <div className="mb-12 text-center">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-gray-900 tracking-tight mb-3">
              Simple pricing.
            </h2>
            <p className="text-gray-500 text-lg">Free plan available now. Paid plans launching with Deepgram this summer.</p>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {/* Free Plan - Available Now */}
            <div className="p-8 lg:p-10 rounded-2xl border-2 border-blue-600 bg-white relative shadow-lg shadow-blue-600/[0.06]">
              <div className="absolute -top-3 left-6 px-3 py-0.5 bg-blue-600 text-white text-xs font-bold rounded-full uppercase tracking-wider">
                Available Now
              </div>

              <div className="flex items-baseline gap-2 mb-1">
                <span className="font-[family-name:var(--font-display)] text-5xl font-bold text-gray-900">$0</span>
                <span className="text-gray-400">forever</span>
              </div>
              <p className="text-sm text-gray-400 mb-8">The Free plan — everything on-device.</p>

              <div className="grid gap-y-3 mb-8">
                {[
                  "Unlimited recording",
                  "On-device AI transcription (WhisperKit)",
                  "AI summaries (3 per month)",
                  "Exam prep mode (Q&A)",
                  "12 languages",
                  "Synced audio playback",
                  "Bookmarks & search",
                  "PDF & Markdown export",
                  "Web sync at lecsy.app",
                ].map((f) => (
                  <div key={f} className="flex items-center gap-3 text-sm text-gray-700">
                    <CheckIcon className="w-4 h-4 text-blue-600 flex-shrink-0" />
                    {f}
                  </div>
                ))}
              </div>

              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="block w-full text-center h-12 leading-[3rem] rounded-xl bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
              >
                Download Free
              </a>
            </div>

            {/* Paid Plans - Coming Soon */}
            <div className="p-8 lg:p-10 rounded-2xl border-2 border-dashed border-indigo-300 bg-gradient-to-br from-indigo-50 to-blue-50 relative">
              <div className="absolute -top-3 left-6 px-3 py-0.5 bg-gradient-to-r from-indigo-600 to-blue-600 text-white text-xs font-bold rounded-full uppercase tracking-wider">
                Coming Soon
              </div>

              <div className="flex items-baseline gap-2 mb-1">
                <span className="font-[family-name:var(--font-display)] text-5xl font-bold text-gray-900">$7.99+</span>
                <span className="text-gray-400">/month</span>
              </div>
              <p className="text-sm text-gray-500 mb-8">Student / Pro / Power — unlocked with Deepgram.</p>

              <div className="grid gap-y-3 mb-8">
                {[
                  "Real-time bilingual captions (Deepgram)",
                  "Live translation in 7+ languages",
                  "Unlimited AI Study Guide",
                  "Unlimited Anki / Quizlet export",
                  "Exam Prep Plan generator",
                  "Priority support",
                ].map((f) => (
                  <div key={f} className="flex items-center gap-3 text-sm text-gray-700">
                    <svg className="w-4 h-4 text-indigo-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span>{f}</span>
                  </div>
                ))}
              </div>

              <a
                href="mailto:support@lecsy.app?subject=Lecsy%20Beta%20Waitlist"
                className="block w-full text-center h-12 leading-[3rem] rounded-xl bg-gradient-to-r from-indigo-600 to-blue-600 text-white text-sm font-semibold hover:opacity-90 transition-opacity"
              >
                Join the Waitlist
              </a>

              <div className="mt-6 pt-6 border-t border-indigo-200">
                <Link
                  href="/pricing"
                  className="inline-block text-sm font-semibold text-indigo-600 hover:text-indigo-800 hover:underline"
                >
                  View detailed paid plans →
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ FAQ ━━━ */}
      <section id="faq" className="bg-gray-50 py-20 lg:py-28">
        <div className="max-w-3xl mx-auto px-5">
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-gray-900 tracking-tight mb-12">
            Questions & answers
          </h2>
          <div className="space-y-3">
            {[
              {
                q: "Is my data safe?",
                a: "Yes. Audio is streamed to Deepgram (our speech-to-text provider) over an encrypted connection for real-time transcription, and Deepgram automatically deletes processed audio within 30 days. Lecsy itself never stores your audio. Transcript text syncs to our cloud only if you sign in. AI features send transcript text only (never audio) to OpenAI. See our Privacy Policy for details."
              },
              {
                q: "Do I need internet to record and transcribe?",
                a: "Real-time bilingual captions require internet (audio is streamed to Deepgram). If you're offline, the recording is still saved on your device and you can transcribe it later when you reconnect."
              },
              {
                q: "What languages are supported?",
                a: "Lecsy supports 12 languages including English, Japanese, Spanish, French, German, Chinese, Korean, and more. You can also get AI summaries in a different language than the recording \u2014 record in English, read the summary in Japanese."
              },
              {
                q: "How does this compare to Otter.ai?",
                a: "Lecsy is built specifically for international students with real-time bilingual captions (vs Otter's English-only). Lecsy Pro is $12.99/month vs Otter's $16.99/month, and Lecsy has a permanent Free plan (on-device only)."
              },
              {
                q: "Is it legal to record lectures?",
                a: "In most US and UK universities, recording lectures for personal study is permitted. Many schools actively encourage it as an accessibility tool. Always check your specific university\u2019s policy."
              },
              {
                q: "How accurate is the transcription?",
                a: "Lecsy uses Deepgram Nova-3 multilingual model. Accuracy is typically 95%+ for clear English lecture audio and 90%+ for non-native speakers. Sitting closer to the speaker helps."
              },
              {
                q: "What iPhones are supported?",
                a: "Any iPhone running iOS 17.6 or later. iPhone 12 and newer recommended for best transcription speed."
              },
              {
                q: "Is Lecsy really free?",
                a: "The Free plan is permanently free: on-device recording, AI Study Guide (3 per month), and transcript sync. Real-time bilingual captions and unlimited AI require Pro ($12.99/mo) or Student ($7.99/mo)."
              },
              {
                q: "What data goes to OpenAI?",
                a: "Only your transcript text, and only when you tap the AI Summary or Exam Mode button. Audio is never sent. OpenAI does not use API content to train its models. We don\u2019t train on your data either."
              },
            ].map((item) => (
              <details key={item.q} className="group bg-white rounded-xl border border-gray-200">
                <summary className="flex items-center justify-between p-5 cursor-pointer select-none">
                  <h3 className="font-semibold text-gray-900 text-sm pr-4">{item.q}</h3>
                  <svg
                    className="w-4 h-4 text-gray-400 group-open:rotate-45 transition-transform flex-shrink-0"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                  </svg>
                </summary>
                <p className="px-5 pb-5 text-gray-500 text-sm leading-relaxed">{item.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ FINAL CTA ━━━ */}
      <section className="bg-blue-600 py-20 lg:py-28 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-400/30 rounded-full blur-[120px] pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-blue-800/40 rounded-full blur-[100px] pointer-events-none" />

        <div className="relative max-w-3xl mx-auto px-5 text-center">
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-bold text-white tracking-tight mb-4">
            Never miss a word again
          </h2>
          <p className="text-blue-100 text-lg mb-10 max-w-lg mx-auto">
            Join students who record, transcribe, and ace their exams — Free plan always available.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="group inline-flex items-center gap-3 h-12 px-6 rounded-xl bg-white text-blue-600 font-semibold text-sm hover:bg-blue-50 transition-all shadow-lg"
            >
              <AppleIcon className="w-5 h-5" />
              Download for iPhone
              <svg className="w-4 h-4 opacity-50 group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </a>
            <Link
              href="/login"
              className="inline-flex items-center justify-center h-12 px-6 rounded-xl border-2 border-white/30 text-white font-medium text-sm hover:bg-white/10 transition-all"
            >
              Open Web App
            </Link>
          </div>
        </div>
      </section>

      {/* ━━━ FOOTER ━━━ */}
      <footer className="bg-white border-t border-gray-100 py-16">
        <div className="max-w-6xl mx-auto px-5">
          <div className="grid md:grid-cols-4 gap-10 mb-12">
            <div>
              <div className="font-[family-name:var(--font-display)] text-xl font-bold text-blue-600 mb-3">
                lecsy
              </div>
              <p className="text-gray-400 text-sm leading-relaxed">
                Free lecture recording & AI transcription.
                <br />
                Built by an independent developer, for students.
              </p>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-4">Features</h4>
              <ul className="space-y-2.5 text-sm text-gray-500">
                <li>
                  <Link href="/ai-transcription-for-students" className="hover:text-gray-900 transition-colors">
                    AI Transcription
                  </Link>
                </li>
                <li>
                  <Link href="/lecture-recording-app-college" className="hover:text-gray-900 transition-colors">
                    Lecture Recording
                  </Link>
                </li>
                <li>
                  <Link href="/ai-note-taking-for-international-students" className="hover:text-gray-900 transition-colors">
                    International Students
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-4">Compare</h4>
              <ul className="space-y-2.5 text-sm text-gray-500">
                <li>
                  <Link href="/otter-alternative-for-lectures" className="hover:text-gray-900 transition-colors">
                    Otter.ai Alternative
                  </Link>
                </li>
                <li>
                  <Link href="/how-to-record-lectures-legally" className="hover:text-gray-900 transition-colors">
                    Recording Legally
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-4">Legal</h4>
              <ul className="space-y-2.5 text-sm text-gray-500">
                <li>
                  <Link href="/privacy" className="hover:text-gray-900 transition-colors">
                    Privacy Policy
                  </Link>
                </li>
                <li>
                  <Link href="/terms" className="hover:text-gray-900 transition-colors">
                    Terms of Service
                  </Link>
                </li>
                <li>
                  <Link href="/support" className="hover:text-gray-900 transition-colors">
                    Support
                  </Link>
                </li>
                <li>
                  <a href="mailto:support@lecsy.app" className="hover:text-gray-900 transition-colors">
                    Contact
                  </a>
                </li>
              </ul>
            </div>
          </div>
          <div className="border-t border-gray-100 pt-8 text-center text-gray-400 text-xs">
            &copy; 2026 Lecsy. All rights reserved.
          </div>
        </div>
      </footer>
    </main>
  );
}
