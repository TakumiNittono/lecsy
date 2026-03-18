import Link from "next/link";
import type { Metadata } from "next";
import { Space_Grotesk } from "next/font/google";
import { APP_STORE_URL } from "@/lib/constants";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-display",
});

export const metadata: Metadata = {
  title: "Lecsy | Free Lecture Recording & AI Transcription App for Students",
  description:
    "Record lectures on iPhone, transcribe with AI 100% offline. Free unlimited recording. Save $204/year vs Otter.ai. Privacy-first — your voice never leaves your device.",
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
};

/* ─── Inline SVG Icons ─── */

function CheckIcon({ className = "w-5 h-5 text-emerald-400" }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
    </svg>
  );
}

function XIcon() {
  return (
    <svg className="w-5 h-5 text-red-400/60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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

/* ─── Waveform decoration ─── */

function Waveform() {
  return (
    <div className="flex items-end gap-[3px] h-8" aria-hidden="true">
      {[40, 70, 55, 85, 45, 90, 60, 75, 50, 80, 35, 65, 95, 55, 70, 40, 85, 50, 75, 60].map(
        (h, i) => (
          <div
            key={i}
            className="w-[3px] rounded-full bg-emerald-400/80"
            style={{
              height: `${h}%`,
              animationDelay: `${i * 0.08}s`,
            }}
          />
        )
      )}
    </div>
  );
}

/* ─── Page ─── */

export default function Home() {
  return (
    <main className={`${spaceGrotesk.variable} min-h-screen`}>
      {/* ── JSON-LD ── */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "FAQPage",
            mainEntity: [
              { "@type": "Question", name: "Is my data safe with Lecsy?", acceptedAnswer: { "@type": "Answer", text: "Yes. All audio recording and transcription happens entirely on your iPhone. Your voice never leaves your device. Only text is saved to the cloud when you choose to sync." } },
              { "@type": "Question", name: "Do I need internet to record and transcribe?", acceptedAnswer: { "@type": "Answer", text: "No. Recording and AI transcription work 100% offline. Perfect for lecture halls with poor WiFi." } },
              { "@type": "Question", name: "What languages does Lecsy support?", acceptedAnswer: { "@type": "Answer", text: "Lecsy currently supports English transcription, optimized for lectures and academic content. More languages are planned for future updates." } },
              { "@type": "Question", name: "How does Lecsy compare to Otter.ai?", acceptedAnswer: { "@type": "Answer", text: "Lecsy offers unlimited free recording (Otter limits to 300min/month), works completely offline (Otter requires internet), costs $0 vs $16.99/month, and keeps your data private on-device." } },
              { "@type": "Question", name: "Is it legal to record lectures?", acceptedAnswer: { "@type": "Answer", text: "In most universities, recording lectures for personal study is permitted. Check your university's policy. Many schools encourage it as an accessibility accommodation." } },
              { "@type": "Question", name: "How accurate is the transcription?", acceptedAnswer: { "@type": "Answer", text: "Lecsy uses OpenAI's Whisper AI model running locally on your device. Accuracy is comparable to cloud-based services, typically 85-95% for clear audio." } },
              { "@type": "Question", name: "Will there be a Pro version?", acceptedAnswer: { "@type": "Answer", text: "We're considering a Pro plan with AI summaries and exam prep features. The core app — recording, transcription, export, and sync — will always be free." } },
              { "@type": "Question", name: "What iPhones are supported?", acceptedAnswer: { "@type": "Answer", text: "Lecsy requires iOS 17.6 or later. iPhone 12 and newer recommended for best transcription speed." } },
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
            description: "Free lecture recording and AI transcription app. Record unlimited lectures, transcribe offline with AI, review on any device.",
            url: "https://www.lecsy.app/",
            downloadUrl: APP_STORE_URL,
            author: { "@type": "Person", name: "Takumi Nittono" },
            aggregateRating: { "@type": "AggregateRating", ratingValue: "5.0", ratingCount: "1" },
          }),
        }}
      />

      {/* ━━━ HEADER ━━━ */}
      <header className="fixed top-0 w-full z-50 border-b border-white/[0.06] bg-[#09090b]/80 backdrop-blur-xl">
        <div className="max-w-6xl mx-auto px-5 h-14 flex items-center justify-between">
          <Link
            href="/"
            className="font-[family-name:var(--font-display)] text-xl font-bold tracking-tight text-white"
          >
            lecsy
          </Link>

          <nav className="hidden md:flex items-center gap-8 text-[13px] text-zinc-400">
            <Link href="#compare" className="hover:text-white transition-colors">
              Compare
            </Link>
            <Link href="#how-it-works" className="hover:text-white transition-colors">
              How it works
            </Link>
            <Link href="#pricing" className="hover:text-white transition-colors">
              Pricing
            </Link>
            <Link href="#faq" className="hover:text-white transition-colors">
              FAQ
            </Link>
          </nav>

          <div className="flex items-center gap-3">
            <Link
              href="/login"
              className="text-[13px] text-zinc-400 hover:text-white transition-colors hidden sm:block"
            >
              Log in
            </Link>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="h-8 px-4 flex items-center gap-2 rounded-full bg-white text-[#09090b] text-[13px] font-semibold hover:bg-zinc-200 transition-colors"
            >
              <AppleIcon className="w-4 h-4" />
              Download
            </a>
          </div>
        </div>
      </header>

      {/* ━━━ HERO ━━━ */}
      <section className="relative bg-[#09090b] pt-32 pb-20 lg:pt-44 lg:pb-32 overflow-hidden">
        {/* Noise texture overlay */}
        <div
          className="absolute inset-0 opacity-[0.035] pointer-events-none"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E")`,
            backgroundRepeat: "repeat",
            backgroundSize: "128px 128px",
          }}
        />
        {/* Subtle radial glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-emerald-500/[0.07] rounded-full blur-[120px] pointer-events-none" />

        <div className="relative max-w-6xl mx-auto px-5">
          <div className="max-w-3xl animate-fade-in-up">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 mb-8 px-3 py-1.5 rounded-full border border-emerald-500/20 bg-emerald-500/[0.08]">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="text-xs font-medium text-emerald-400 tracking-wide uppercase">
                Free forever &middot; No limits
              </span>
            </div>

            {/* Headline */}
            <h1 className="font-[family-name:var(--font-display)] text-[clamp(2.5rem,7vw,5.5rem)] font-bold leading-[0.95] tracking-tight text-white mb-6">
              Your lectures,
              <br />
              <span className="text-emerald-400">transcribed.</span>
            </h1>

            {/* Subtitle */}
            <p className="text-lg lg:text-xl text-zinc-400 leading-relaxed max-w-xl mb-10">
              AI transcription that runs entirely on your iPhone.
              <br className="hidden sm:block" />
              Offline. Private. Unlimited. <span className="text-white font-medium">$0.</span>
            </p>

            {/* CTAs */}
            <div className="flex flex-col sm:flex-row gap-3">
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="group inline-flex items-center justify-center gap-3 h-12 px-6 rounded-xl bg-white text-[#09090b] font-semibold text-sm hover:bg-zinc-200 transition-all"
              >
                <AppleIcon className="w-5 h-5" />
                Download for iPhone
                <svg className="w-4 h-4 text-zinc-400 group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </a>
              <Link
                href="/login"
                className="inline-flex items-center justify-center h-12 px-6 rounded-xl border border-zinc-700 text-zinc-300 font-medium text-sm hover:border-zinc-500 hover:text-white transition-all"
              >
                Open Web App
              </Link>
            </div>
          </div>

          {/* Right side - floating card */}
          <div className="hidden lg:block absolute right-0 top-1/2 -translate-y-1/2 w-72">
            <div className="bg-zinc-900/80 backdrop-blur border border-zinc-800 rounded-2xl p-6 space-y-5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Recording</span>
                <span className="flex items-center gap-1.5 text-xs text-emerald-400 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  Live
                </span>
              </div>
              <Waveform />
              <div className="space-y-2">
                <div className="h-2 bg-zinc-800 rounded-full w-full" />
                <div className="h-2 bg-zinc-800 rounded-full w-4/5" />
                <div className="h-2 bg-zinc-800 rounded-full w-3/5" />
                <div className="h-2 bg-emerald-500/20 rounded-full w-2/3" />
              </div>
              <div className="flex items-center gap-2 text-xs text-zinc-500">
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
      <section className="bg-[#09090b] border-t border-zinc-800/50">
        <div className="max-w-6xl mx-auto px-5 py-10 grid grid-cols-2 md:grid-cols-4 gap-8">
          {[
            { value: "$0", label: "Forever free", accent: true },
            { value: "\u221E", label: "Recording minutes" },
            { value: "100%", label: "Offline capable" },
            { value: "0", label: "Data sent to cloud", suffix: "bytes" },
          ].map((stat) => (
            <div key={stat.label} className="text-center">
              <div
                className={`font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold tracking-tight ${
                  stat.accent ? "text-emerald-400" : "text-white"
                }`}
              >
                {stat.value}
                {stat.suffix && (
                  <span className="text-base font-normal text-zinc-500 ml-1">{stat.suffix}</span>
                )}
              </div>
              <div className="text-sm text-zinc-500 mt-1">{stat.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ━━━ COMPARISON ━━━ */}
      <section id="compare" className="bg-[#09090b] py-20 lg:py-28">
        <div className="max-w-4xl mx-auto px-5">
          <div className="mb-12">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-white tracking-tight mb-3">
              Why students switch
            </h2>
            <p className="text-zinc-500 text-lg">
              Otter charges $17/mo and needs WiFi. You deserve better.
            </p>
          </div>

          <div className="rounded-2xl border border-zinc-800 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-zinc-800">
                    <th className="text-left p-4 text-zinc-500 font-medium w-2/5" />
                    <th className="p-4 text-center">
                      <span className="font-[family-name:var(--font-display)] text-lg font-bold text-emerald-400">
                        Lecsy
                      </span>
                    </th>
                    <th className="p-4 text-center">
                      <span className="text-zinc-500 font-medium">Otter.ai</span>
                    </th>
                    <th className="p-4 text-center">
                      <span className="text-zinc-500 font-medium">Notta</span>
                    </th>
                  </tr>
                </thead>
                <tbody className="text-zinc-300">
                  {[
                    { feature: "Price", lecsy: "FREE", otter: "$16.99/mo", notta: "$13.99/mo", highlight: true },
                    { feature: "Monthly minutes", lecsy: "Unlimited", otter: "300 min", notta: "120 min" },
                    { feature: "Works offline", lecsy: true, otter: false, notta: false },
                    { feature: "On-device AI", lecsy: true, otter: false, notta: false },
                    { feature: "Privacy (on-device)", lecsy: true, otter: false, notta: false },
                    { feature: "Annual cost", lecsy: "$0", otter: "$203.88", notta: "$167.88", strikeOthers: true },
                  ].map((row, i) => (
                    <tr key={row.feature} className={`border-b border-zinc-800/50 ${i % 2 === 0 ? "bg-zinc-900/30" : ""}`}>
                      <td className="p-4 font-medium text-zinc-400">{row.feature}</td>
                      <td className="p-4 text-center">
                        {typeof row.lecsy === "boolean" ? (
                          row.lecsy ? <CheckIcon /> : <XIcon />
                        ) : (
                          <span className={`font-bold ${row.highlight ? "text-emerald-400 text-lg" : "text-white"}`}>
                            {row.lecsy}
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-center">
                        {typeof row.otter === "boolean" ? (
                          row.otter ? <CheckIcon /> : <XIcon />
                        ) : (
                          <span className={row.strikeOthers ? "line-through text-zinc-600" : "text-zinc-500"}>
                            {row.otter}
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-center">
                        {typeof row.notta === "boolean" ? (
                          row.notta ? <CheckIcon /> : <XIcon />
                        ) : (
                          <span className={row.strikeOthers ? "line-through text-zinc-600" : "text-zinc-500"}>
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

          <p className="mt-6 inline-flex items-center gap-2 px-4 py-2 rounded-full border border-emerald-500/20 bg-emerald-500/[0.06] text-sm text-emerald-400 font-medium">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Save up to $204/year with Lecsy
          </p>
        </div>
      </section>

      {/* ━━━ HOW IT WORKS ━━━ */}
      <section id="how-it-works" className="bg-[#fafaf9] py-20 lg:py-28">
        <div className="max-w-5xl mx-auto px-5">
          <div className="mb-16">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-zinc-900 tracking-tight mb-3">
              Three taps to better grades
            </h2>
            <p className="text-zinc-500 text-lg">No account required. Just open and record.</p>
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
                desc: "AI converts speech to text on your device. No internet. No upload. Powered by OpenAI Whisper.",
                icon: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
              },
              {
                step: "03",
                title: "Review",
                desc: "Search, bookmark, export. Read on your phone or laptop. Ace your exams.",
                icon: "M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z",
              },
            ].map((item) => (
              <div
                key={item.step}
                className="group relative p-8 rounded-2xl border border-zinc-200 bg-white hover-lift"
              >
                <span className="font-[family-name:var(--font-display)] text-5xl font-bold text-zinc-100 group-hover:text-emerald-100 transition-colors absolute top-6 right-6">
                  {item.step}
                </span>
                <div className="w-10 h-10 rounded-xl bg-zinc-900 flex items-center justify-center mb-6">
                  <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d={item.icon} />
                  </svg>
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-xl font-bold text-zinc-900 mb-2">
                  {item.title}
                </h3>
                <p className="text-zinc-500 text-sm leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ FEATURES BENTO ━━━ */}
      <section className="bg-white py-20 lg:py-28">
        <div className="max-w-5xl mx-auto px-5">
          <div className="mb-16">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-zinc-900 tracking-tight mb-3">
              Built for how students actually study
            </h2>
          </div>

          <div className="grid md:grid-cols-6 gap-4">
            {/* Large card - Privacy */}
            <div className="md:col-span-4 p-8 rounded-2xl bg-zinc-900 text-white relative overflow-hidden group">
              <div className="absolute top-0 right-0 w-48 h-48 bg-emerald-500/10 rounded-full blur-[80px] pointer-events-none" />
              <div className="relative">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/10 flex items-center justify-center mb-5">
                  <svg className="w-5 h-5 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-xl font-bold mb-2">
                  100% Private
                </h3>
                <p className="text-zinc-400 text-sm leading-relaxed max-w-sm">
                  Audio never leaves your device. All AI processing happens locally on your
                  iPhone&apos;s neural engine. No cloud. No data mining. Ever.
                </p>
              </div>
            </div>

            {/* Small card - Speed */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-zinc-200 bg-zinc-50 flex flex-col justify-between">
              <svg className="w-5 h-5 text-zinc-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              <div>
                <h3 className="font-[family-name:var(--font-display)] font-bold text-zinc-900 mb-1">
                  Instant Transcription
                </h3>
                <p className="text-zinc-500 text-xs leading-relaxed">
                  Stop recording, get your text. Powered by Whisper on-device.
                </p>
              </div>
            </div>

            {/* Small card - Bookmarks */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-zinc-200 bg-zinc-50 flex flex-col justify-between">
              <svg className="w-5 h-5 text-zinc-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
              </svg>
              <div>
                <h3 className="font-[family-name:var(--font-display)] font-bold text-zinc-900 mb-1">
                  Bookmarks & Search
                </h3>
                <p className="text-zinc-500 text-xs leading-relaxed">
                  Mark key moments. Full-text search across all lectures.
                </p>
              </div>
            </div>

            {/* Medium card - Export */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-zinc-200 bg-zinc-50">
              <svg className="w-5 h-5 text-zinc-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <h3 className="font-[family-name:var(--font-display)] font-bold text-zinc-900 mb-1">
                Export Anywhere
              </h3>
              <p className="text-zinc-500 text-xs leading-relaxed">
                PDF with timestamps. Markdown for notes apps. Share links with classmates.
              </p>
            </div>

            {/* Medium card - Synced */}
            <div className="md:col-span-2 p-6 rounded-2xl border border-zinc-200 bg-zinc-50">
              <svg className="w-5 h-5 text-zinc-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 className="font-[family-name:var(--font-display)] font-bold text-zinc-900 mb-1">
                Synced Playback
              </h3>
              <p className="text-zinc-500 text-xs leading-relaxed">
                Audio and text move together. Tap any sentence to jump. 0.75x to 2x speed.
              </p>
            </div>

            {/* Large card - Cross device */}
            <div className="md:col-span-4 p-8 rounded-2xl border border-zinc-200 bg-zinc-50 relative overflow-hidden">
              <svg className="w-5 h-5 text-zinc-400 mb-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <h3 className="font-[family-name:var(--font-display)] text-xl font-bold text-zinc-900 mb-2">
                Read on Any Device
              </h3>
              <p className="text-zinc-500 text-sm leading-relaxed max-w-md">
                Sync transcripts to the web with one tap. Review on your laptop before exams.
                Search across your entire lecture library.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ TESTIMONIALS ━━━ */}
      <section className="bg-[#fafaf9] py-20 lg:py-28">
        <div className="max-w-5xl mx-auto px-5">
          <div className="mb-12">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-zinc-900 tracking-tight mb-3">
              Students love Lecsy
            </h2>
            <p className="text-zinc-500">Made by a student, for students.</p>
          </div>

          <div className="grid md:grid-cols-3 gap-4">
            {[
              {
                quote:
                  "I used to pay $17/month for Otter and it didn't even work in our lecture hall because of bad WiFi. Lecsy works offline and it's free. No-brainer.",
                name: "Sarah K.",
                role: "Computer Science, UCLA",
              },
              {
                quote:
                  "As an international student, being able to record and re-read lectures at my own pace is a game changer. I finally understand everything.",
                name: "Yuki T.",
                role: "Business, University of Melbourne",
              },
              {
                quote:
                  "The privacy aspect sold me. My lecture recordings stay on my phone, not on some company's servers. And the transcription quality is surprisingly good.",
                name: "Marcus R.",
                role: "Pre-Med, NYU",
              },
            ].map((t) => (
              <div
                key={t.name}
                className="p-6 rounded-2xl bg-white border border-zinc-200 flex flex-col justify-between"
              >
                <div>
                  <div className="flex gap-0.5 mb-4">
                    {[1, 2, 3, 4, 5].map((i) => (
                      <svg key={i} className="w-4 h-4 text-amber-400" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                      </svg>
                    ))}
                  </div>
                  <p className="text-zinc-600 text-sm leading-relaxed mb-6">
                    &ldquo;{t.quote}&rdquo;
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-zinc-200 flex items-center justify-center text-xs font-bold text-zinc-500">
                    {t.name.charAt(0)}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-zinc-900">{t.name}</p>
                    <p className="text-xs text-zinc-400">{t.role}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ PRICING ━━━ */}
      <section id="pricing" className="bg-white py-20 lg:py-28">
        <div className="max-w-4xl mx-auto px-5">
          <div className="mb-12">
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-zinc-900 tracking-tight mb-3">
              Student-friendly pricing
            </h2>
            <p className="text-zinc-500 text-lg">Everything you need is free. No catch.</p>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {/* Free */}
            <div className="p-8 rounded-2xl border-2 border-zinc-900 bg-white relative">
              <div className="absolute -top-3 left-6 px-3 py-0.5 bg-zinc-900 text-white text-xs font-bold rounded-full uppercase tracking-wider">
                Current
              </div>
              <h3 className="font-[family-name:var(--font-display)] text-2xl font-bold text-zinc-900 mb-1">
                Free
              </h3>
              <div className="flex items-baseline gap-1 mb-1">
                <span className="font-[family-name:var(--font-display)] text-5xl font-bold text-zinc-900">$0</span>
              </div>
              <p className="text-sm text-zinc-400 mb-8">Forever. No credit card.</p>
              <ul className="space-y-3 mb-8">
                {[
                  "Unlimited recording",
                  "Offline AI transcription",
                  "English optimized",
                  "Synced audio playback",
                  "Bookmarks & search",
                  "PDF & Markdown export",
                  "Web sync",
                  "Study streak tracking",
                ].map((f) => (
                  <li key={f} className="flex items-center gap-3 text-sm text-zinc-700">
                    <CheckIcon className="w-4 h-4 text-emerald-500 flex-shrink-0" />
                    {f}
                  </li>
                ))}
              </ul>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="block w-full text-center h-11 leading-[2.75rem] rounded-xl bg-zinc-900 text-white text-sm font-semibold hover:bg-zinc-800 transition-colors"
              >
                Download Free
              </a>
            </div>

            {/* Pro */}
            <div className="p-8 rounded-2xl bg-zinc-100 border border-zinc-200 relative">
              <div className="absolute -top-3 left-6 px-3 py-0.5 bg-amber-400 text-amber-900 text-xs font-bold rounded-full uppercase tracking-wider">
                Coming Soon
              </div>
              <h3 className="font-[family-name:var(--font-display)] text-2xl font-bold text-zinc-900 mb-1">
                Pro
              </h3>
              <div className="flex items-baseline gap-1 mb-1">
                <span className="font-[family-name:var(--font-display)] text-5xl font-bold text-zinc-300">TBD</span>
              </div>
              <p className="text-sm text-zinc-400 mb-8">We&apos;re working on it</p>
              <ul className="space-y-3 mb-8">
                {[
                  "Everything in Free",
                  "AI-powered summaries",
                  "Key points extraction",
                  "Exam prep mode (Q&A)",
                  "Section breakdown",
                ].map((f) => (
                  <li key={f} className="flex items-center gap-3 text-sm text-zinc-400">
                    <CheckIcon className="w-4 h-4 text-zinc-300 flex-shrink-0" />
                    {f}
                  </li>
                ))}
              </ul>
              <div className="block w-full text-center h-11 leading-[2.75rem] rounded-xl bg-zinc-200 text-zinc-400 text-sm font-semibold cursor-default">
                Coming Soon
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ FAQ ━━━ */}
      <section id="faq" className="bg-[#fafaf9] py-20 lg:py-28">
        <div className="max-w-3xl mx-auto px-5">
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold text-zinc-900 tracking-tight mb-12">
            Questions & answers
          </h2>
          <div className="space-y-3">
            {[
              { q: "Is my data safe?", a: "Yes. All audio recording and transcription happens entirely on your iPhone. Your voice never leaves your device. Only text is saved to the cloud when you explicitly choose to sync." },
              { q: "Do I need internet to record and transcribe?", a: "No. Recording and AI transcription work 100% offline. You only need internet for the initial one-time AI model download (~150MB) and for syncing transcripts to the web." },
              { q: "What languages are supported?", a: "Lecsy currently supports English, optimized for lectures and academic content. We're exploring adding more languages in future updates." },
              { q: "How does this compare to Otter.ai?", a: "Lecsy offers unlimited free recording (vs 300 min/month), works 100% offline (vs internet required), costs $0 (vs $16.99/month), and keeps all data on your device (vs cloud processing). You save over $200/year." },
              { q: "Is it legal to record lectures?", a: "In most US and UK universities, recording lectures for personal study is permitted. Many schools actively encourage it as an accessibility tool. Always check your specific university's policy." },
              { q: "How accurate is the transcription?", a: "Lecsy uses OpenAI's Whisper model running locally. Accuracy is typically 85-95% for clear English audio, comparable to cloud services. Quality depends on recording conditions — sitting closer to the speaker helps." },
              { q: "What iPhones are supported?", a: "Any iPhone running iOS 17.6 or later. iPhone 12 and newer are recommended for the best transcription speed. Older models work but transcription may take longer." },
              { q: "Will there be a paid version?", a: "We're considering a Pro plan with AI summaries and exam prep features. The core app — unlimited recording, transcription, export, and sync — will always be free." },
            ].map((item) => (
              <details key={item.q} className="group bg-white rounded-xl border border-zinc-200">
                <summary className="flex items-center justify-between p-5 cursor-pointer select-none">
                  <h3 className="font-semibold text-zinc-900 text-sm pr-4">{item.q}</h3>
                  <svg
                    className="w-4 h-4 text-zinc-400 group-open:rotate-45 transition-transform flex-shrink-0"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                  </svg>
                </summary>
                <p className="px-5 pb-5 text-zinc-500 text-sm leading-relaxed">{item.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ FINAL CTA ━━━ */}
      <section className="bg-[#09090b] py-20 lg:py-28 relative overflow-hidden">
        <div
          className="absolute inset-0 opacity-[0.03] pointer-events-none"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E")`,
            backgroundRepeat: "repeat",
            backgroundSize: "128px 128px",
          }}
        />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-emerald-500/[0.05] rounded-full blur-[100px] pointer-events-none" />

        <div className="relative max-w-3xl mx-auto px-5 text-center">
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-bold text-white tracking-tight mb-4">
            Never miss a word again
          </h2>
          <p className="text-zinc-400 text-lg mb-10 max-w-lg mx-auto">
            Join students who record, transcribe, and ace their exams — completely free.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="group inline-flex items-center gap-3 h-12 px-6 rounded-xl bg-white text-[#09090b] font-semibold text-sm hover:bg-zinc-200 transition-all"
            >
              <AppleIcon className="w-5 h-5" />
              Download for iPhone
              <svg className="w-4 h-4 text-zinc-400 group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </a>
            <Link
              href="/login"
              className="inline-flex items-center justify-center h-12 px-6 rounded-xl border border-zinc-700 text-zinc-300 font-medium text-sm hover:border-zinc-500 hover:text-white transition-all"
            >
              Open Web App
            </Link>
          </div>
        </div>
      </section>

      {/* ━━━ FOOTER ━━━ */}
      <footer className="bg-[#09090b] border-t border-zinc-800/50 py-16">
        <div className="max-w-6xl mx-auto px-5">
          <div className="grid md:grid-cols-4 gap-10 mb-12">
            <div>
              <div className="font-[family-name:var(--font-display)] text-xl font-bold text-white mb-3">
                lecsy
              </div>
              <p className="text-zinc-500 text-sm leading-relaxed">
                Free lecture recording & AI transcription.
                <br />
                Built by a student, for students.
              </p>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-4">Features</h4>
              <ul className="space-y-2.5 text-sm text-zinc-500">
                <li>
                  <Link href="/ai-transcription-for-students" className="hover:text-white transition-colors">
                    AI Transcription
                  </Link>
                </li>
                <li>
                  <Link href="/lecture-recording-app-college" className="hover:text-white transition-colors">
                    Lecture Recording
                  </Link>
                </li>
                <li>
                  <Link href="/ai-note-taking-for-international-students" className="hover:text-white transition-colors">
                    International Students
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-4">Compare</h4>
              <ul className="space-y-2.5 text-sm text-zinc-500">
                <li>
                  <Link href="/otter-alternative-for-lectures" className="hover:text-white transition-colors">
                    Otter.ai Alternative
                  </Link>
                </li>
                <li>
                  <Link href="/how-to-record-lectures-legally" className="hover:text-white transition-colors">
                    Recording Legally
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-4">Legal</h4>
              <ul className="space-y-2.5 text-sm text-zinc-500">
                <li>
                  <Link href="/privacy" className="hover:text-white transition-colors">
                    Privacy Policy
                  </Link>
                </li>
                <li>
                  <Link href="/terms" className="hover:text-white transition-colors">
                    Terms of Service
                  </Link>
                </li>
              </ul>
            </div>
          </div>
          <div className="border-t border-zinc-800/50 pt-8 text-center text-zinc-600 text-xs">
            &copy; 2026 Lecsy. All rights reserved.
          </div>
        </div>
      </footer>
    </main>
  );
}
