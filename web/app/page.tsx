import Link from "next/link";
import Image from "next/image";
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
    "Record lectures on iPhone. Free plan transcribes on-device in 9 languages. Paid plans add real-time bilingual captions via Deepgram. AI summaries & study guides for international students. Lecsy never stores your audio.",
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
};

/* ─── Icons ─── */

function CheckIcon({ className = "w-5 h-5" }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
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

function ArrowIcon({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
    </svg>
  );
}

/* ─── Animated waveform ─── */

function Waveform({ tone = "deep" }: { tone?: "deep" | "light" }) {
  const heights = [40, 70, 55, 85, 45, 90, 60, 75, 50, 80, 35, 65, 95, 55, 70, 40, 85, 50, 75, 60];
  const color = tone === "deep" ? "bg-[var(--brand-deep)]" : "bg-white/85";
  return (
    <div className="flex items-end gap-[3px] h-10" aria-hidden="true">
      {heights.map((h, i) => (
        <div
          key={i}
          className={`wave-bar w-[3px] rounded-full ${color}`}
          style={{ height: `${h}%`, animationDelay: `${(i % 10) * 0.08}s` }}
        />
      ))}
    </div>
  );
}

/* ─── Page ─── */

export default function Home() {
  return (
    <main className={`${spaceGrotesk.variable} min-h-screen bg-white text-[var(--ink)]`}>
      {/* ── JSON-LD ── */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "FAQPage",
            mainEntity: [
              { "@type": "Question", name: "Is my data safe with Lecsy?", acceptedAnswer: { "@type": "Answer", text: "Your audio file (.m4a) is always saved only on your iPhone — there is no code path that uploads it. On the Free plan, transcription also runs entirely on your iPhone using WhisperKit, so audio never leaves your device. On paid plans, live audio is streamed over an encrypted connection to Deepgram for real-time transcription, and Deepgram automatically deletes it within 30 days; Lecsy itself never stores audio on its servers. Transcript text syncs to our cloud only when you sign in. AI features send transcript text only (never audio) to OpenAI." } },
              { "@type": "Question", name: "Do I need internet to record and transcribe?", acceptedAnswer: { "@type": "Answer", text: "On the Free plan, recording and transcription work fully offline (WhisperKit on-device). On paid plans, real-time bilingual captions require internet because the audio is streamed to Deepgram. If you're offline on a paid plan, the recording is still saved locally and you can transcribe later, or switch to on-device mode in Settings." } },
              { "@type": "Question", name: "What languages does Lecsy support?", acceptedAnswer: { "@type": "Answer", text: "Lecsy supports 9 languages for transcription: English, Japanese, Spanish, French, German, Portuguese, Italian, Russian, and Hindi. AI summaries can be generated in a different language than the recording." } },
              { "@type": "Question", name: "How does Lecsy compare to Otter.ai?", acceptedAnswer: { "@type": "Answer", text: "Lecsy is built specifically for international students. The Free plan transcribes on-device with WhisperKit (audio never leaves your iPhone). Paid plans add real-time bilingual captions via Deepgram, which auto-deletes audio within 30 days; Lecsy never stores audio on its servers. Lecsy Pro is $12.99/month vs Otter's $16.99/month, and Lecsy has a permanent Free plan." } },
              { "@type": "Question", name: "Is it legal to record lectures?", acceptedAnswer: { "@type": "Answer", text: "In most universities, recording lectures for personal study is permitted. Many schools encourage it as an accessibility accommodation. Check your university's policy." } },
              { "@type": "Question", name: "How accurate is the transcription?", acceptedAnswer: { "@type": "Answer", text: "On paid plans, Lecsy uses Deepgram Nova-3 multilingual model — accuracy is typically 95%+ for clear English lecture audio and 90%+ for non-native speakers. The Free plan uses Apple's WhisperKit on-device, which is slower but works offline and keeps audio on your iPhone." } },
              { "@type": "Question", name: "Is Lecsy really free?", acceptedAnswer: { "@type": "Answer", text: "The Free plan is permanently free: on-device recording and transcription (WhisperKit), AI Study Guide (3 per month), and transcript sync. Upgrade to Pro ($12.99/month) or Student ($7.99/month) for real-time bilingual captions via Deepgram and unlimited AI features." } },
              { "@type": "Question", name: "What about AI summaries — does my data go to a server?", acceptedAnswer: { "@type": "Answer", text: "When you tap AI Summary or Exam Mode, only the transcript text (never audio) is sent to OpenAI's GPT-4o-mini to generate the summary. OpenAI does not use API content to train its models. The audio file always stays on your iPhone." } },
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
            description: "Free lecture recording and AI study app. Record unlimited lectures, transcribe offline, get AI summaries and exam prep in 9 languages.",
            url: "https://www.lecsy.app/",
            downloadUrl: APP_STORE_URL,
            author: { "@type": "Person", name: "Takumi Nittono" },
          }),
        }}
      />

      {/* ━━━ HEADER ━━━ */}
      <header className="fixed top-0 w-full z-50 border-b border-[#E6EEFB] bg-white/75 backdrop-blur-xl">
        <div className="max-w-6xl mx-auto px-5 h-14 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2.5">
            <span className="relative w-7 h-7 rounded-[8px] overflow-hidden ring-1 ring-[#E6EEFB] shadow-sm">
              <Image src="/icon.png" alt="" width={28} height={28} className="object-cover" />
            </span>
            <span className="font-[family-name:var(--font-display)] text-xl font-semibold tracking-tight text-[var(--ink)]">
              lecsy
            </span>
          </Link>

          <nav className="hidden md:flex items-center gap-8 text-[13px] text-[var(--ink-soft)]">
            <Link href="#how" className="hover:text-[var(--ink)] transition-colors">How it works</Link>
            <Link href="#features" className="hover:text-[var(--ink)] transition-colors">Features</Link>
            <Link href="#pricing" className="hover:text-[var(--ink)] transition-colors">Pricing</Link>
            <Link href="#faq" className="hover:text-[var(--ink)] transition-colors">FAQ</Link>
          </nav>

          <div className="flex items-center gap-3">
            {/*
              B2C web 動線は B2B 招待パイロット期間中は非表示。
              個人ユーザーは iOS アプリへ誘導する。
            */}
            {false && (
              <Link
                href="/login"
                className="text-[13px] text-[var(--ink-mute)] hover:text-[var(--ink)] transition-colors hidden sm:block"
              >
                Log in
              </Link>
            )}
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="h-8 px-4 flex items-center gap-2 rounded-full bg-[var(--brand-deep)] text-white text-[13px] font-semibold hover:bg-[var(--brand-mid)] transition-colors"
            >
              <AppleIcon className="w-4 h-4" />
              Download
            </a>
          </div>
        </div>
      </header>

      {/* ━━━ HERO ━━━ */}
      <section className="relative pt-28 pb-24 lg:pt-36 lg:pb-32 overflow-hidden mesh-flow">
        <div className="relative max-w-6xl mx-auto px-5">
          <div className="grid lg:grid-cols-12 gap-12 items-center">
            <div className="lg:col-span-7 animate-fade-in-up">
              <div className="inline-flex items-center gap-2 px-3 py-1 mb-6 text-[11px] font-medium tracking-[0.16em] uppercase text-[var(--brand-deep)] bg-white/70 backdrop-blur rounded-full ring-1 ring-[#D6E4FB]">
                <span className="w-1.5 h-1.5 rounded-full bg-[var(--brand-deep)]" />
                iPhone · 9 languages · offline
              </div>

              <h1 className="font-[family-name:var(--font-display)] text-[clamp(2.75rem,7.5vw,5.75rem)] font-semibold leading-[0.98] tracking-tight text-[var(--ink)] mb-6">
                Lectures,
                <br />
                <span className="bg-[linear-gradient(118deg,var(--brand-deep),var(--brand-bright))] bg-clip-text text-transparent">
                  in your language.
                </span>
              </h1>

              <p className="text-lg lg:text-xl text-[var(--ink-soft)] leading-relaxed max-w-xl mb-10">
                Lecsy records your class on iPhone, transcribes it on-device in&nbsp;9 languages,
                and turns it into an AI summary you can actually study from.
              </p>

              <div className="flex flex-col sm:flex-row gap-3">
                <a
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group inline-flex items-center justify-center gap-3 h-12 px-6 rounded-full bg-[var(--brand-deep)] text-white font-semibold text-sm shadow-[0_10px_30px_-10px_rgba(30,91,217,0.55)] hover:bg-[var(--brand-mid)] transition-all"
                >
                  <AppleIcon className="w-5 h-5" />
                  Download for iPhone
                  <ArrowIcon className="w-4 h-4 opacity-70 group-hover:translate-x-0.5 transition-transform" />
                </a>
                <Link
                  href="#how"
                  className="inline-flex items-center justify-center h-12 px-6 rounded-full border border-[#CFDBF3] text-[var(--ink)] font-medium text-sm hover:border-[var(--brand-deep)] hover:text-[var(--brand-deep)] transition-all bg-white/60 backdrop-blur"
                >
                  See how it works
                </Link>
              </div>

              <div className="mt-8 flex items-center gap-4 text-xs text-[var(--ink-mute)]">
                <span className="flex items-center gap-1.5">
                  <CheckIcon className="w-3.5 h-3.5 text-[var(--brand-deep)]" />
                  Free, forever
                </span>
                <span className="text-[#CFDBF3]">·</span>
                <span className="flex items-center gap-1.5">
                  <CheckIcon className="w-3.5 h-3.5 text-[var(--brand-deep)]" />
                  Audio stays on your iPhone
                </span>
                <span className="hidden sm:inline text-[#CFDBF3]">·</span>
                <span className="hidden sm:flex items-center gap-1.5">
                  <CheckIcon className="w-3.5 h-3.5 text-[var(--brand-deep)]" />
                  No ads, no trackers
                </span>
              </div>
            </div>

            {/* Right column — app icon + live recording card */}
            <div className="lg:col-span-5 relative">
              <div className="relative mx-auto max-w-sm float-y">
                <div className="absolute -inset-6 -z-10 rounded-[36px] bg-[radial-gradient(circle_at_30%_30%,rgba(96,165,250,0.35),transparent_60%)] blur-2xl" />

                {/* App icon */}
                <div className="relative mx-auto w-24 h-24 rounded-[22px] overflow-hidden ring-1 ring-white/80 shadow-[0_20px_60px_-15px_rgba(30,91,217,0.4)] mb-6">
                  <Image src="/icon.png" alt="Lecsy app icon" width={96} height={96} priority />
                </div>

                {/* Recording card */}
                <div className="rounded-[22px] bg-white/90 backdrop-blur-xl border border-white shadow-[0_30px_80px_-30px_rgba(30,91,217,0.35)] p-6 space-y-5">
                  <div className="flex items-center justify-between">
                    <span className="text-[10px] font-semibold text-[var(--ink-mute)] uppercase tracking-[0.18em]">
                      Now recording
                    </span>
                    <span className="flex items-center gap-1.5 text-xs font-medium text-[var(--ink)]">
                      <span className="w-1.5 h-1.5 rounded-full bg-[var(--brand-deep)]" />
                      Live
                    </span>
                  </div>

                  <Waveform />

                  <div className="space-y-2">
                    <div className="h-2 rounded-full bg-[var(--brand-sky)] w-full" />
                    <div className="h-2 rounded-full bg-[var(--brand-sky)] w-4/5" />
                    <div className="h-2 rounded-full bg-[var(--brand-sky)] w-3/5" />
                    <div className="h-2 rounded-full bg-[#D6E4FB] w-2/3" />
                  </div>

                  <div className="flex items-center gap-2 text-[11px] text-[var(--ink-mute)]">
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    </svg>
                    On-device · Audio never uploaded
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ STATS BAR ━━━ */}
      <section className="border-y border-[#E6EEFB] bg-white">
        <div className="max-w-6xl mx-auto px-5 py-10 grid grid-cols-2 md:grid-cols-4 gap-8">
          {[
            { value: "$0", label: "Free plan, forever", accent: true },
            { value: "∞", label: "Recording minutes" },
            { value: "9", label: "Languages supported" },
            { value: "0", label: "Audio on our servers", suffix: "bytes" },
          ].map((stat) => (
            <div key={stat.label} className="text-center">
              <div
                className={`font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-bold tracking-tight ${
                  stat.accent ? "text-[var(--brand-deep)]" : "text-[var(--ink)]"
                }`}
              >
                {stat.value}
                {stat.suffix && (
                  <span className="text-base font-normal text-[var(--ink-mute)] ml-1">{stat.suffix}</span>
                )}
              </div>
              <div className="text-sm text-[var(--ink-soft)] mt-1">{stat.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ━━━ HOW IT WORKS ━━━ */}
      <section id="how" className="relative py-24 lg:py-32 bg-[var(--brand-mist)] overflow-hidden">
        <div className="relative max-w-6xl mx-auto px-5">
          <div className="max-w-2xl mb-16">
            <span className="inline-block text-xs font-semibold tracking-[0.18em] uppercase text-[var(--brand-deep)] mb-4">
              What Lecsy does
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold text-[var(--ink)] tracking-tight mb-4 leading-tight">
              Three taps from class to study notes.
            </h2>
            <p className="text-lg text-[var(--ink-soft)]">
              No setup. No account required. Open the app and hit record — the rest happens for you.
            </p>
          </div>

          {/* Connector flow */}
          <div className="relative">
            <div
              aria-hidden
              className="hidden md:block absolute top-[88px] left-[10%] right-[10%] h-px bg-[linear-gradient(90deg,transparent,#9DBDF0,#3B82F6,#9DBDF0,transparent)] opacity-60"
            />
            <div className="grid md:grid-cols-3 gap-6 relative">
              {[
                {
                  step: "01",
                  title: "Record",
                  desc: "Open Lecsy, tap record. Keeps running with the screen locked, in the background, all the way through a 90-minute class.",
                  icon: "M12 1.5a3.5 3.5 0 00-3.5 3.5v6a3.5 3.5 0 007 0V5A3.5 3.5 0 0012 1.5zM5 11a7 7 0 0014 0M12 18v4M8 22h8",
                },
                {
                  step: "02",
                  title: "Transcribe",
                  desc: "Free: WhisperKit transcribes on your iPhone, fully offline. Paid: Deepgram Nova-3 streams real-time bilingual captions. 9 languages either way.",
                  icon: "M4 6h16M4 12h10M4 18h16",
                },
                {
                  step: "03",
                  title: "Study",
                  desc: "Get an AI summary, key terms, and a list of likely exam questions — generated from the transcript, in the language you want to read in.",
                  icon: "M12 6.5v11M6.5 12h11M19 7v10a2 2 0 01-2 2H7a2 2 0 01-2-2V7a2 2 0 012-2h10a2 2 0 012 2z",
                },
              ].map((item, i) => (
                <div
                  key={item.step}
                  className={`group relative p-8 rounded-3xl bg-white border border-[#E6EEFB] card-lift animate-fade-in-up reveal-${i + 1}`}
                >
                  <div className="flex items-start justify-between mb-6">
                    <div className="w-12 h-12 rounded-2xl brand-diagonal flex items-center justify-center shadow-[0_10px_24px_-10px_rgba(30,91,217,0.55)]">
                      <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d={item.icon} />
                      </svg>
                    </div>
                    <span className="font-[family-name:var(--font-display)] text-sm font-semibold tracking-[0.2em] text-[var(--brand-deep)]/40">
                      {item.step}
                    </span>
                  </div>
                  <h3 className="font-[family-name:var(--font-display)] text-2xl font-semibold text-[var(--ink)] mb-2 tracking-tight">
                    {item.title}
                  </h3>
                  <p className="text-[15px] text-[var(--ink-soft)] leading-relaxed">{item.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ BILINGUAL ━━━ */}
      <section className="relative py-24 lg:py-32 bg-white overflow-hidden">
        <div
          aria-hidden
          className="absolute inset-x-0 top-0 h-px bg-[linear-gradient(90deg,transparent,#D6E4FB,transparent)]"
        />
        <div className="relative max-w-5xl mx-auto px-5">
          <div className="text-center mb-14">
            <span className="inline-block text-xs font-semibold tracking-[0.18em] uppercase text-[var(--brand-deep)] mb-4">
              Bilingual study
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold text-[var(--ink)] tracking-tight mb-5 leading-tight">
              Lectures in English. <br className="hidden md:inline" />
              Notes in your language.
            </h2>
            <p className="text-lg text-[var(--ink-soft)] max-w-2xl mx-auto">
              You passed TOEFL. You still struggle to follow a fast-talking professor.
              Lecsy gives you the original transcript and the summary in your language — side by side.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-5 max-w-3xl mx-auto mb-14">
            <div className="rounded-2xl p-6 bg-white border border-[#E6EEFB] card-lift">
              <div className="flex items-center gap-2 mb-3">
                <span className="w-1.5 h-1.5 rounded-full bg-[var(--brand-bright)]" />
                <span className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--brand-deep)]">
                  English transcript
                </span>
              </div>
              <p className="text-sm text-[var(--ink)] leading-relaxed mb-4">
                This lecture covered the mechanism of cell division and how it functions in the development
                of multicellular organisms, with particular focus on the difference between mitosis and meiosis.
              </p>
              <div className="text-[11px] font-semibold text-[var(--ink-mute)] uppercase tracking-wider mb-2">
                Key Points
              </div>
              <ul className="space-y-1.5 text-sm text-[var(--ink-soft)]">
                <li>• Mitosis = two daughter cells with identical DNA</li>
                <li>• Meiosis = gamete formation, chromosome halving</li>
                <li>• Checkpoints ensure division quality</li>
              </ul>
            </div>

            <div className="rounded-2xl p-6 brand-diagonal text-white card-lift relative overflow-hidden">
              <div
                aria-hidden
                className="absolute -top-10 -right-10 w-40 h-40 rounded-full bg-white/10 blur-2xl"
              />
              <div className="relative">
                <div className="flex items-center gap-2 mb-3">
                  <span className="w-1.5 h-1.5 rounded-full bg-white" />
                  <span className="text-[11px] font-semibold uppercase tracking-[0.16em] text-white/85">
                    日本語サマリー
                  </span>
                </div>
                <p className="text-sm leading-relaxed mb-4">
                  この講義では細胞分裂のしくみと、それが多細胞生物の発生でどう働くかを扱いました。
                  特に有糸分裂と減数分裂のちがいに焦点が当てられています。
                </p>
                <div className="text-[11px] font-semibold uppercase tracking-wider text-white/70 mb-2">
                  要点
                </div>
                <ul className="space-y-1.5 text-sm text-white/90">
                  <li>• 有糸分裂 = 同じ DNA を持つ娘細胞 2 つ</li>
                  <li>• 減数分裂 = 配偶子をつくる、染色体半減</li>
                  <li>• チェックポイントが分裂の品質を担保</li>
                </ul>
              </div>
            </div>
          </div>

          {/* Languages chip row */}
          <div className="flex flex-wrap justify-center gap-2 max-w-2xl mx-auto">
            {["English", "日本語", "Español", "Français", "Deutsch", "Português", "Italiano", "Русский", "हिन्दी"].map((lang) => (
              <span
                key={lang}
                className="px-3.5 py-1.5 rounded-full bg-[var(--brand-sky)] text-[var(--brand-deep)] text-xs font-medium ring-1 ring-[#D6E4FB]"
              >
                {lang}
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ FEATURES BENTO ━━━ */}
      <section id="features" className="bg-[var(--brand-mist)] py-24 lg:py-32">
        <div className="max-w-6xl mx-auto px-5">
          <div className="max-w-2xl mb-14">
            <span className="inline-block text-xs font-semibold tracking-[0.18em] uppercase text-[var(--brand-deep)] mb-4">
              Built for how you study
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold text-[var(--ink)] tracking-tight leading-tight">
              Everything in one place.
            </h2>
          </div>

          <div className="grid md:grid-cols-6 gap-4">
            {/* Big — Privacy story */}
            <div className="md:col-span-4 relative overflow-hidden p-8 lg:p-10 rounded-3xl mesh-deep text-white card-lift">
              <div className="relative max-w-md">
                <div className="w-11 h-11 rounded-2xl bg-white/15 backdrop-blur flex items-center justify-center mb-6 ring-1 ring-white/25">
                  <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-2xl lg:text-3xl font-semibold tracking-tight mb-3 leading-tight">
                  Your audio<br />never leaves your iPhone.
                </h3>
                <p className="text-white/75 text-sm leading-relaxed">
                  The .m4a file stays on your phone — there is no upload code path, on any plan.
                  Free transcribes on-device with WhisperKit. On paid plans, the live stream goes
                  to Deepgram and is auto-deleted within 30 days. No ads, no trackers, no IDFA.
                </p>
              </div>
            </div>

            {/* AI Summaries */}
            <div className="md:col-span-2 p-7 rounded-3xl bg-white border border-[#E6EEFB] card-lift">
              <div className="w-10 h-10 rounded-xl bg-[var(--brand-sky)] flex items-center justify-center mb-5">
                <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                </svg>
              </div>
              <h3 className="font-[family-name:var(--font-display)] font-semibold text-[var(--ink)] mb-1.5 text-lg tracking-tight">
                AI Summaries
              </h3>
              <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                Key points, section outlines, and definitions — written in the language you study in.
              </p>
            </div>

            {/* Exam Mode */}
            <div className="md:col-span-2 p-7 rounded-3xl bg-white border border-[#E6EEFB] card-lift">
              <div className="w-10 h-10 rounded-xl bg-[var(--brand-sky)] flex items-center justify-center mb-5">
                <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                </svg>
              </div>
              <h3 className="font-[family-name:var(--font-display)] font-semibold text-[var(--ink)] mb-1.5 text-lg tracking-tight">
                Exam Mode
              </h3>
              <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                AI generates likely test questions with model answers from your lecture.
              </p>
            </div>

            {/* Offline */}
            <div className="md:col-span-2 p-7 rounded-3xl bg-white border border-[#E6EEFB] card-lift">
              <div className="w-10 h-10 rounded-xl bg-[var(--brand-sky)] flex items-center justify-center mb-5">
                <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M18.364 5.636a9 9 0 11-12.728 0M12 3v9" />
                </svg>
              </div>
              <h3 className="font-[family-name:var(--font-display)] font-semibold text-[var(--ink)] mb-1.5 text-lg tracking-tight">
                Works Offline
              </h3>
              <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                Free plan transcribes on-device — perfect for lecture halls without Wi-Fi.
              </p>
            </div>

            {/* 9 Languages */}
            <div className="md:col-span-2 p-7 rounded-3xl bg-white border border-[#E6EEFB] card-lift">
              <div className="w-10 h-10 rounded-xl bg-[var(--brand-sky)] flex items-center justify-center mb-5">
                <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
                </svg>
              </div>
              <h3 className="font-[family-name:var(--font-display)] font-semibold text-[var(--ink)] mb-1.5 text-lg tracking-tight">
                9 Languages
              </h3>
              <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                Record in English, read the summary in Japanese — or any of nine languages.
              </p>
            </div>

            {/* Synced Playback */}
            <div className="md:col-span-2 p-7 rounded-3xl bg-white border border-[#E6EEFB] card-lift">
              <div className="w-10 h-10 rounded-xl bg-[var(--brand-sky)] flex items-center justify-center mb-5">
                <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="font-[family-name:var(--font-display)] font-semibold text-[var(--ink)] mb-1.5 text-lg tracking-tight">
                Synced Playback
              </h3>
              <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                Audio and text move together. Tap any sentence to jump. 0.75× to 2× speed.
              </p>
            </div>

            {/* Cross-device */}
            <div className="md:col-span-4 relative overflow-hidden p-8 lg:p-10 rounded-3xl bg-white border border-[#E6EEFB] card-lift">
              <div
                aria-hidden
                className="absolute -bottom-16 -right-10 w-72 h-72 rounded-full bg-[radial-gradient(circle,rgba(96,165,250,0.18),transparent_65%)]"
              />
              <div className="relative max-w-md">
                <div className="w-11 h-11 rounded-2xl bg-[var(--brand-sky)] flex items-center justify-center mb-6">
                  <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-2xl font-semibold text-[var(--ink)] mb-2 tracking-tight">
                  Read on any device.
                </h3>
                <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                  Sync transcripts to the web with one tap. Review on your laptop before exams.
                  Search across your entire lecture library at lecsy.app.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ DATA TRANSPARENCY ━━━ */}
      <section className="bg-white py-24 lg:py-32">
        <div className="max-w-4xl mx-auto px-5">
          <div className="mb-12">
            <span className="inline-block text-xs font-semibold tracking-[0.18em] uppercase text-[var(--brand-deep)] mb-4">
              What happens to your data
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold text-[var(--ink)] tracking-tight mb-3 leading-tight">
              No fine print.
            </h2>
            <p className="text-[var(--ink-soft)] text-lg">Here&apos;s the honest version of where your data goes.</p>
          </div>

          <div className="space-y-3">
            {[
              {
                icon: "M12 1.5a3.5 3.5 0 00-3.5 3.5v6a3.5 3.5 0 007 0V5A3.5 3.5 0 0012 1.5zM5 11a7 7 0 0014 0M12 18v4M8 22h8",
                title: "Audio (.m4a)",
                status: "Never leaves your iPhone",
                tone: "good",
                desc: "There is no code path in Lecsy that uploads your audio file. Not to our servers, not to OpenAI, not anywhere.",
              },
              {
                icon: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
                title: "Transcript text",
                status: "Synced if signed in (toggleable)",
                tone: "neutral",
                desc: "When you're signed in, transcript text backs up so you can recover it if you lose your phone. Turn off anytime in Settings → Privacy → Cloud Sync.",
              },
              {
                icon: "M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z",
                title: "AI Summary & Exam Mode",
                status: "Text sent to OpenAI on demand",
                tone: "neutral",
                desc: "Only the transcript text (never audio) goes to GPT-4o-mini when you tap the button. OpenAI does not use API content to train its models.",
              },
              {
                icon: "M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636",
                title: "Ads, trackers, IDFA",
                status: "None",
                tone: "good",
                desc: "No ad SDKs. No third-party analytics. No IDFA tracking. We don’t sell your data.",
              },
            ].map((item) => (
              <div
                key={item.title}
                className="bg-white rounded-2xl p-6 border border-[#E6EEFB] flex gap-5 card-lift"
              >
                <div className="w-11 h-11 rounded-xl bg-[var(--brand-sky)] flex items-center justify-center flex-shrink-0">
                  <svg className="w-5 h-5 text-[var(--brand-deep)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d={item.icon} />
                  </svg>
                </div>
                <div>
                  <div className="flex flex-wrap items-baseline gap-2 mb-1">
                    <h3 className="font-semibold text-[var(--ink)]">{item.title}</h3>
                    <span
                      className={`text-[11px] font-semibold px-2 py-0.5 rounded-full ${
                        item.tone === "good"
                          ? "bg-[var(--brand-sky)] text-[var(--brand-deep)]"
                          : "bg-[#FFF4E0] text-[#A06800]"
                      }`}
                    >
                      {item.status}
                    </span>
                  </div>
                  <p className="text-sm text-[var(--ink-soft)] leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ PRICING ━━━ */}
      <section id="pricing" className="bg-[var(--brand-mist)] py-24 lg:py-32">
        <div className="max-w-3xl mx-auto px-5">
          <div className="mb-12 text-center">
            <span className="inline-block text-xs font-semibold tracking-[0.18em] uppercase text-[var(--brand-deep)] mb-4">
              Pricing
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold text-[var(--ink)] tracking-tight mb-4 leading-tight">
              Simple. And free.
            </h2>
            <p className="text-[var(--ink-soft)] text-lg">
              The Free plan covers the whole flow. Paid plans unlock real-time bilingual captions.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-5">
            {/* Free */}
            <div className="relative p-8 lg:p-10 rounded-3xl bg-white border-2 border-[var(--brand-deep)] shadow-[0_30px_70px_-30px_rgba(30,91,217,0.35)]">
              <div className="absolute -top-3 left-6 px-3 py-0.5 bg-[var(--brand-deep)] text-white text-[10px] font-bold rounded-full uppercase tracking-[0.16em]">
                Available now
              </div>

              <div className="flex items-baseline gap-2 mb-1">
                <span className="font-[family-name:var(--font-display)] text-5xl font-semibold tracking-tight text-[var(--ink)]">$0</span>
                <span className="text-[var(--ink-mute)]">forever</span>
              </div>
              <p className="text-sm text-[var(--ink-soft)] mb-8">Everything on-device. No account needed.</p>

              <div className="grid gap-y-2.5 mb-8">
                {[
                  "Unlimited recording",
                  "On-device transcription (WhisperKit)",
                  "AI summaries (3 per month)",
                  "Exam prep mode (Q&A)",
                  "9 languages",
                  "Synced audio playback",
                  "Bookmarks & search",
                  "PDF & Markdown export",
                  "Web sync at lecsy.app",
                ].map((f) => (
                  <div key={f} className="flex items-center gap-3 text-sm text-[var(--ink)]">
                    <CheckIcon className="w-4 h-4 text-[var(--brand-deep)] flex-shrink-0" />
                    {f}
                  </div>
                ))}
              </div>

              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="block w-full text-center h-12 leading-[3rem] rounded-full bg-[var(--brand-deep)] text-white text-sm font-semibold hover:bg-[var(--brand-mid)] transition-colors"
              >
                Download Free
              </a>
            </div>

            {/* Paid */}
            <div className="relative p-8 lg:p-10 rounded-3xl bg-white border border-[#E6EEFB]">
              <div className="absolute -top-3 left-6 px-3 py-0.5 bg-[var(--ink)] text-white text-[10px] font-bold rounded-full uppercase tracking-[0.16em]">
                Coming soon
              </div>

              <div className="flex items-baseline gap-2 mb-1">
                <span className="font-[family-name:var(--font-display)] text-5xl font-semibold tracking-tight text-[var(--ink)]">$7.99+</span>
                <span className="text-[var(--ink-mute)]">/month</span>
              </div>
              <p className="text-sm text-[var(--ink-soft)] mb-8">Student / Pro — real-time captions via Deepgram.</p>

              <div className="grid gap-y-2.5 mb-8">
                {[
                  "Real-time bilingual captions (Deepgram)",
                  "Live translation in 7+ languages",
                  "Unlimited AI Study Guide",
                  "Unlimited Anki / Quizlet export",
                  "Exam Prep Plan generator",
                  "Priority support",
                ].map((f) => (
                  <div key={f} className="flex items-center gap-3 text-sm text-[var(--ink-soft)]">
                    <svg className="w-4 h-4 text-[var(--ink-mute)] flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span>{f}</span>
                  </div>
                ))}
              </div>

              <a
                href="mailto:support@lecsy.app?subject=Lecsy%20Beta%20Waitlist"
                className="block w-full text-center h-12 leading-[3rem] rounded-full border border-[var(--ink)] text-[var(--ink)] text-sm font-semibold hover:bg-[var(--ink)] hover:text-white transition-colors"
              >
                Join the waitlist
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* ━━━ FAQ ━━━ */}
      <section id="faq" className="bg-white py-24 lg:py-32">
        <div className="max-w-3xl mx-auto px-5">
          <div className="mb-12">
            <span className="inline-block text-xs font-semibold tracking-[0.18em] uppercase text-[var(--brand-deep)] mb-4">
              FAQ
            </span>
            <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold text-[var(--ink)] tracking-tight leading-tight">
              Questions, answered.
            </h2>
          </div>
          <div className="space-y-3">
            {[
              {
                q: "Is my data safe?",
                a: "Your audio file (.m4a) is always saved only on your iPhone — there is no code path that uploads it. On the Free plan, transcription also runs entirely on your iPhone (WhisperKit), so audio never leaves your device. On paid plans, live audio is streamed over an encrypted connection to Deepgram for real-time transcription; Deepgram automatically deletes it within 30 days, and Lecsy itself never stores audio on its servers. Transcript text syncs to our cloud only if you sign in. AI features send transcript text only (never audio) to OpenAI."
              },
              {
                q: "Do I need internet to record and transcribe?",
                a: "On the Free plan, recording and transcription work fully offline (WhisperKit on-device). On paid plans, real-time bilingual captions require internet because audio is streamed to Deepgram. If you're offline on a paid plan, the recording is still saved locally and you can transcribe later, or switch to on-device mode in Settings → Transcription Method."
              },
              {
                q: "What languages are supported?",
                a: "Lecsy supports 9 languages for transcription: English, Japanese, Spanish, French, German, Portuguese, Italian, Russian, and Hindi. You can also get AI summaries in a different language than the recording — record in English, read the summary in Japanese."
              },
              {
                q: "How accurate is the transcription?",
                a: "On paid plans, Lecsy uses Deepgram Nova-3 multilingual model — typically 95%+ for clear English lecture audio and 90%+ for non-native speakers. The Free plan uses Apple's WhisperKit on-device, which is a bit slower but works offline and keeps audio on your iPhone."
              },
              {
                q: "Is it legal to record lectures?",
                a: "In most US and UK universities, recording lectures for personal study is permitted. Many schools actively encourage it as an accessibility tool. Always check your specific university's policy."
              },
              {
                q: "What iPhones are supported?",
                a: "Any iPhone running iOS 17.6 or later. iPhone 12 and newer recommended for best transcription speed."
              },
              {
                q: "Is Lecsy really free?",
                a: "The Free plan is permanently free: on-device recording and transcription (WhisperKit), AI Study Guide (3 per month), and transcript sync. Real-time bilingual captions via Deepgram and unlimited AI require Pro ($12.99/mo) or Student ($7.99/mo)."
              },
              {
                q: "What data goes to OpenAI?",
                a: "Only your transcript text, and only when you tap the AI Summary or Exam Mode button. The audio file is never sent. OpenAI does not use API content to train its models."
              },
            ].map((item) => (
              <details key={item.q} className="group bg-white rounded-2xl border border-[#E6EEFB] open:border-[#CFDBF3] transition-colors">
                <summary className="flex items-center justify-between p-5 cursor-pointer select-none">
                  <h3 className="font-semibold text-[var(--ink)] text-sm pr-4">{item.q}</h3>
                  <svg
                    className="w-4 h-4 text-[var(--brand-deep)] group-open:rotate-45 transition-transform flex-shrink-0"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                  </svg>
                </summary>
                <p className="px-5 pb-5 text-[var(--ink-soft)] text-sm leading-relaxed">{item.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ━━━ FINAL CTA ━━━ */}
      <section className="relative py-28 lg:py-36 overflow-hidden mesh-deep">
        <div className="relative max-w-3xl mx-auto px-5 text-center">
          <h2 className="font-[family-name:var(--font-display)] text-4xl lg:text-6xl font-semibold text-white tracking-tight mb-5 leading-[1.05]">
            Never miss a word.
          </h2>
          <p className="text-white/75 text-lg mb-10 max-w-lg mx-auto">
            Record, transcribe, and ace your exams. Free plan, always.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="group inline-flex items-center gap-3 h-12 px-6 rounded-full bg-white text-[var(--brand-deep)] font-semibold text-sm hover:bg-[var(--brand-sky)] transition-all"
            >
              <AppleIcon className="w-5 h-5" />
              Download for iPhone
              <ArrowIcon className="w-4 h-4 opacity-70 group-hover:translate-x-0.5 transition-transform" />
            </a>
            <Link
              href="#how"
              className="inline-flex items-center justify-center h-12 px-6 rounded-full border border-white/30 text-white font-medium text-sm hover:bg-white/10 transition-all"
            >
              See how it works
            </Link>
          </div>
        </div>
      </section>

      {/* ━━━ FOOTER ━━━ */}
      <footer className="bg-white border-t border-[#E6EEFB] py-16">
        <div className="max-w-6xl mx-auto px-5">
          <div className="grid md:grid-cols-4 gap-10 mb-12">
            <div>
              <Link href="/" className="flex items-center gap-2.5 mb-3">
                <span className="relative w-7 h-7 rounded-[8px] overflow-hidden ring-1 ring-[#E6EEFB]">
                  <Image src="/icon.png" alt="" width={28} height={28} className="object-cover" />
                </span>
                <span className="font-[family-name:var(--font-display)] text-xl font-semibold tracking-tight text-[var(--ink)]">
                  lecsy
                </span>
              </Link>
              <p className="text-[var(--ink-soft)] text-sm leading-relaxed">
                Free lecture recording & AI transcription.
                <br />
                Built by an independent developer, for students.
              </p>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-[var(--ink-mute)] uppercase tracking-wider mb-4">Features</h4>
              <ul className="space-y-2.5 text-sm text-[var(--ink-soft)]">
                <li>
                  <Link href="/ai-transcription-for-students" className="hover:text-[var(--ink)] transition-colors">
                    AI Transcription
                  </Link>
                </li>
                <li>
                  <Link href="/lecture-recording-app-college" className="hover:text-[var(--ink)] transition-colors">
                    Lecture Recording
                  </Link>
                </li>
                <li>
                  <Link href="/ai-note-taking-for-international-students" className="hover:text-[var(--ink)] transition-colors">
                    International Students
                  </Link>
                </li>
                <li>
                  <Link href="/android" className="hover:text-[var(--ink)] transition-colors">
                    Android (Invite only)
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-[var(--ink-mute)] uppercase tracking-wider mb-4">Compare</h4>
              <ul className="space-y-2.5 text-sm text-[var(--ink-soft)]">
                <li>
                  <Link href="/otter-alternative-for-lectures" className="hover:text-[var(--ink)] transition-colors">
                    Otter.ai Alternative
                  </Link>
                </li>
                <li>
                  <Link href="/how-to-record-lectures-legally" className="hover:text-[var(--ink)] transition-colors">
                    Recording Legally
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-semibold text-[var(--ink-mute)] uppercase tracking-wider mb-4">Legal</h4>
              <ul className="space-y-2.5 text-sm text-[var(--ink-soft)]">
                <li>
                  <Link href="/privacy" className="hover:text-[var(--ink)] transition-colors">
                    Privacy Policy
                  </Link>
                </li>
                <li>
                  <Link href="/terms" className="hover:text-[var(--ink)] transition-colors">
                    Terms of Service
                  </Link>
                </li>
                <li>
                  <Link href="/support" className="hover:text-[var(--ink)] transition-colors">
                    Support
                  </Link>
                </li>
                <li>
                  <a href="mailto:support@lecsy.app" className="hover:text-[var(--ink)] transition-colors">
                    Contact
                  </a>
                </li>
              </ul>
            </div>
          </div>
          <div className="border-t border-[#E6EEFB] pt-8 text-center text-[var(--ink-mute)] text-xs">
            &copy; 2026 Lecsy. All rights reserved.
          </div>
        </div>
      </footer>
    </main>
  );
}
