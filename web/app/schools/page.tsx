import Link from "next/link";
import type { Metadata } from "next";
import FaqAccordion from "./FaqAccordion";

export const metadata: Metadata = {
  title: "Lecture transcription built for ESL and IEP classrooms",
  description:
    "Real-time bilingual lecture transcription designed for intensive English programs. Audio never stored. FERPA-aligned. Free pilot through June 1, 2026.",
  alternates: { canonical: "https://www.lecsy.app/schools" },
};

const FAQ: { q: string; a: string }[] = [
  {
    q: "Who is this for?",
    a: "English Language Institutes, Intensive English Programs, and community-college ESL departments serving international students. Built around the way ESL directors already run their programs — not a repackaged corporate meeting tool.",
  },
  {
    q: "What makes this different from Otter or Notta?",
    a: "Two things: (1) we don't store your audio — Deepgram transcribes it in real time over TLS and the audio is discarded; we only keep the text. (2) Captions can be rendered bilingually (English + the student's native language) side-by-side, live, word-by-word. This is specifically for students who passed TOEFL but still lose 30% of a fast-talking professor.",
  },
  {
    q: "Is audio recorded or uploaded anywhere?",
    a: "No persistent audio is stored by lecsy. Audio is streamed over an encrypted connection to Deepgram for real-time transcription and immediately discarded. The student's iPhone keeps a local .m4a on the device for offline playback; it is never uploaded to our servers.",
  },
  {
    q: "How does this align with FERPA?",
    a: "Classroom audio containing student voices is treated as FERPA-relevant. Because we don't retain audio and because transcript text is scoped to the organization (RLS enforced in our database), disclosure is limited to program members. A FERPA Addendum and full DPA are available on request — email founder@lecsy.app.",
  },
  {
    q: "What does the pilot cover?",
    a: "Through June 1, 2026, the pilot is completely free for UF ELI and Santa Fe College ESL. Included: the student iPhone app, real-time bilingual captions via Deepgram, AI summaries in 9 languages, an admin dashboard showing program-wide usage, and CSV export. Not included: SSO/SAML, HIPAA BAA, on-prem deployment. See the Pilot page for full scope.",
  },
  {
    q: "What happens after the pilot?",
    a: "We'll put together a proposal that fits your program — seat count, contract term, payment method (P-card / PO / invoice). There is no auto-conversion, no pre-committed price, and no obligation to continue. If it didn't help your students, we walk away.",
  },
];

export default function SchoolsHome() {
  return (
    <>
      {/* HERO */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-[#0B1E3F] via-[#0B1E3F] to-[#16315C]" />
        <div
          className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage:
              "radial-gradient(circle at 25% 10%, white 1px, transparent 1px)",
            backgroundSize: "24px 24px",
          }}
        />

        <div className="relative max-w-5xl mx-auto px-5 pt-24 pb-28 text-white">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-white/20 bg-white/5 backdrop-blur-sm mb-8">
            <span className="w-1.5 h-1.5 rounded-full bg-[#F5C96B]" />
            <span className="text-xs font-medium tracking-wide uppercase text-[#F5D58F]">
              Free pilot through June 1, 2026
            </span>
          </div>

          <h1 className="font-[family-name:var(--font-display)] text-4xl md:text-6xl lg:text-7xl font-semibold leading-[1.05] tracking-tight mb-7 max-w-4xl">
            Lecture transcription,
            <br />
            <span className="text-[#F5C96B]">built for the ESL classroom.</span>
          </h1>

          <p className="text-lg md:text-xl text-[#C8D1E0] leading-relaxed max-w-2xl mb-10">
            Real-time bilingual captions. AI summaries in 9 languages. Program-wide
            admin dashboard. Audio that never touches our servers. Designed specifically for
            Intensive English Programs, IEPs, and community-college ESL departments.
          </p>

          <div className="flex flex-col sm:flex-row gap-3">
            <Link
              href="/schools/demo"
              className="inline-flex items-center justify-center gap-3 px-7 py-3.5rounded-full bg-white text-[#0B1E3F] font-semibold text-[15px] hover:bg-[#F7F5F1] transition-colors"
            >
              Request a free pilot
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
              </svg>
            </Link>
            <Link
              href="/schools/security"
              className="inline-flex items-center justify-center gap-2 px-7 py-3.5rounded-full border border-white/25 text-white font-medium text-[15px] hover:bg-white/5 transition-colors"
            >
              Security & FERPA posture
            </Link>
          </div>

          <div className="mt-14 grid sm:grid-cols-3 gap-10 max-w-3xl text-sm">
            {[
              { label: "Audio stored on our servers", value: "0 bytes" },
              { label: "Languages supported", value: "12" },
              { label: "FERPA-aligned by design", value: "Yes" },
            ].map((s) => (
              <div key={s.label}>
                <div className="font-[family-name:var(--font-display)] text-3xl font-semibold text-white">
                  {s.value}
                </div>
                <div className="text-[#8A9BB5] mt-1">{s.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* DESIGN PARTNERS */}
      <section className="border-b border-[#E5E1D8] bg-[#F7F5F1]">
        <div className="max-w-5xl mx-auto px-5 py-10 text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            In pilot with
          </p>
          <div className="flex flex-wrap items-center justify-center gap-8 md:gap-16">
            <div className="font-[family-name:var(--font-display)] text-xl md:text-2xl font-medium text-[#0B1E3F]">
              University of Florida ELI
            </div>
            <span className="hidden md:block text-[#C8C3B8]">·</span>
            <div className="font-[family-name:var(--font-display)] text-xl md:text-2xl font-medium text-[#0B1E3F]">
              Santa Fe College ESL
            </div>
          </div>
          <p className="text-xs text-[#8A9BB5] mt-4">
            Spring & Summer 2026 cohorts — Gainesville, Florida
          </p>
        </div>
      </section>

      {/* PROBLEM */}
      <section className="py-20 lg:py-28">
        <div className="max-w-4xl mx-auto px-5">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            The problem
          </p>
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-5xl font-semibold leading-[1.1] tracking-tight text-[#0B1E3F] mb-8">
            Your students passed TOEFL.
            <br />
            They still lose 30% of the lecture.
          </h2>
          <div className="prose prose-lg text-[#4A5B74] max-w-3xl leading-relaxed space-y-4">
            <p>
              Intensive English Programs admit students who demonstrated academic English
              proficiency on paper. Inside a classroom with a native-speed professor, lab
              jargon, and a regional accent, that proficiency gets tested in ways no standardized
              exam measures. Students miss content. Teachers repeat material. Persistence suffers.
            </p>
            <p>
              Consumer-grade transcription tools were built for sales calls and Zoom meetings.
              They upload audio to servers without clear retention terms, they don&apos;t
              speak the student&apos;s native language back to them in real time, and they
              leave administrators with no visibility into whether the tool is actually being used.
            </p>
            <p>
              Lecsy was built after watching international students in Gainesville fall behind in
              exactly this way. The product assumptions are different because the user is different.
            </p>
          </div>
        </div>
      </section>

      {/* SOLUTION - THREE PILLARS */}
      <section className="bg-white border-y border-[#E5E1D8]">
        <div className="max-w-6xl mx-auto px-5 py-20 lg:py-28">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            How lecsy is different
          </p>
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-semibold leading-tight tracking-tight text-[#0B1E3F] mb-14 max-w-3xl">
            Three things we decided before writing any code.
          </h2>

          <div className="grid md:grid-cols-3 gap-10 lg:gap-14">
            {[
              {
                kicker: "01",
                title: "Deepgram multilingual, live",
                body: "Real-time captions in 9 languages via Deepgram Nova-3. Students see the professor's words in English and in their native language, side-by-side, word-by-word — not after class, during class.",
              },
              {
                kicker: "02",
                title: "Privacy by retention, not by policy",
                body: "The only way to not lose student audio is to not store it. Audio streams to Deepgram over TLS, transcription comes back as text, audio is discarded. The text lives under organization-scoped RLS inside Supabase Postgres in us-east-1.",
              },
              {
                kicker: "03",
                title: "Printable admin receipts",
                body: "Every program-level number — active students, minutes recorded, languages in use — exports to CSV and prints cleanly. For the administrator who needs to show the accreditor what the program did this semester.",
              },
            ].map((p) => (
              <div key={p.kicker}>
                <div className="text-xs font-mono tracking-widest text-[#8A9BB5] mb-3">
                  {p.kicker}
                </div>
                <h3 className="font-[family-name:var(--font-display)] text-2xl font-semibold text-[#0B1E3F] mb-4 leading-tight">
                  {p.title}
                </h3>
                <p className="text-[#4A5B74] leading-relaxed">{p.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* SECURITY SNAPSHOT */}
      <section className="py-20 lg:py-28">
        <div className="max-w-5xl mx-auto px-5">
          <div className="bg-[#0B1E3F] rounded-3xl px-8 md:px-14 py-14 md:py-20 text-white">
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#F5C96B] mb-4">
              Security snapshot
            </p>
            <h2 className="font-[family-name:var(--font-display)] text-3xl md:text-4xl font-semibold leading-tight mb-8">
              The short answers your IT department will ask first.
            </h2>

            <dl className="grid md:grid-cols-2 gap-x-10 gap-y-6">
              {[
                ["Audio stored by lecsy?", "No. Deepgram transcribes in real time, audio discarded."],
                ["Data residency", "United States — AWS us-east-1 via Supabase."],
                ["Encryption", "TLS 1.2+ in transit, AES-256 at rest."],
                ["Subprocessors", "Deepgram, Supabase, OpenAI, Stripe."],
                ["Data deletion", "30 days from contract termination."],
                ["FERPA posture", "Aligned by design. DPA + FERPA Addendum available."],
              ].map(([term, def]) => (
                <div key={term}>
                  <dt className="text-[#F5D58F] text-xs uppercase tracking-wider mb-1">{term}</dt>
                  <dd className="text-white text-[15px] leading-relaxed">{def}</dd>
                </div>
              ))}
            </dl>

            <div className="mt-10">
              <Link
                href="/schools/security"
                className="inline-flex items-center gap-2 text-[#F5C96B] font-semibold text-[15px] border-b border-[#F5C96B]/40 hover:border-[#F5C96B] transition-colors"
              >
                Read the full security posture
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* WHAT YOU GET IN THE PILOT */}
      <section className="bg-white border-y border-[#E5E1D8]">
        <div className="max-w-5xl mx-auto px-5 py-20 lg:py-28">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            The pilot
          </p>
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-semibold leading-tight text-[#0B1E3F] mb-10">
            Free through June 1, 2026. No obligation after.
          </h2>

          <div className="grid md:grid-cols-2 gap-10">
            <div>
              <h3 className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-5">
                What&apos;s included
              </h3>
              <ul className="space-y-3 text-[#4A5B74]">
                {[
                  "Up to 250 student seats (UF ELI) / 100 seats (Santa Fe)",
                  "Real-time bilingual captions — 9 languages",
                  "AI summaries & exam-prep generation",
                  "Organization admin dashboard with per-student usage",
                  "CSV export of program-wide metrics",
                  "Printable setup guide for your team",
                  "Direct founder support — email & on-campus visits",
                ].map((s) => (
                  <li key={s} className="flex gap-3">
                    <svg className="w-5 h-5 text-[#0B1E3F] flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="leading-relaxed">{s}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <h3 className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-5">
                Not included in the pilot
              </h3>
              <ul className="space-y-3 text-[#8A9BB5]">
                {[
                  "SSO / SAML (planned Q4 2026)",
                  "HIPAA BAA (service not designed for PHI)",
                  "On-premise deployment",
                  "White-label or custom domain",
                ].map((s) => (
                  <li key={s} className="flex gap-3">
                    <svg className="w-5 h-5 text-[#C8C3B8] flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    <span className="leading-relaxed">{s}</span>
                  </li>
                ))}
              </ul>
              <p className="mt-8 text-sm text-[#4A5B74] border-l-2 border-[#F5C96B] pl-4">
                Post-pilot pricing is individual — we&apos;ll put together a proposal that fits your
                program&apos;s seat count, budget cycle, and payment method (P-card, PO, or invoice).
              </p>
            </div>
          </div>

          <div className="mt-14">
            <Link
              href="/schools/pilot"
              className="inline-flex items-center gap-2 text-[#0B1E3F] font-semibold text-[15px] border-b border-[#0B1E3F]/30 hover:border-[#0B1E3F] transition-colors"
            >
              Full pilot terms
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </Link>
          </div>
        </div>
      </section>

      {/* FOUNDER NOTE */}
      <section className="py-20 lg:py-28">
        <div className="max-w-3xl mx-auto px-5">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            Who&apos;s behind this
          </p>
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-semibold leading-tight text-[#0B1E3F] mb-8">
            Built in Gainesville, by an international student.
          </h2>
          <div className="text-[#4A5B74] text-lg leading-relaxed space-y-4">
            <p>
              I&apos;m Takumi. I came to Florida from Japan, and I built lecsy because I watched friends —
              smart, hard-working students — fall behind in classes they had every reason to succeed in.
              The gap wasn&apos;t intelligence. It was 45 minutes of fast-talking lectures per day, in a
              language they were still catching up to.
            </p>
            <p>
              Lecsy is a single-founder product right now. That means when you ask for a change, I answer.
              When your professor&apos;s mic clips, I drive over. This phase of the product is intentionally
              small so we can actually learn what your program needs — not what a software company
              <em> thinks </em> your program needs.
            </p>
            <p className="text-[#0B1E3F] font-medium">— Takumi Nittono, founder · <a href="mailto:founder@lecsy.app" className="underline">founder@lecsy.app</a></p>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="bg-white border-y border-[#E5E1D8]">
        <div className="max-w-3xl mx-auto px-5 py-20 lg:py-28">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            Frequently asked
          </p>
          <h2 className="font-[family-name:var(--font-display)] text-3xl lg:text-4xl font-semibold leading-tight text-[#0B1E3F] mb-10">
            Questions we&apos;ve already been asked.
          </h2>
          <FaqAccordion items={FAQ} />
        </div>
      </section>

      {/* FINAL CTA */}
      <section className="py-24 lg:py-32 bg-[#0B1E3F] text-white text-center">
        <div className="max-w-3xl mx-auto px-5">
          <h2 className="font-[family-name:var(--font-display)] text-4xl md:text-5xl font-semibold leading-[1.1] tracking-tight mb-6">
            15 minutes, on campus.
          </h2>
          <p className="text-[#C8D1E0] text-lg mb-10">
            We&apos;ll bring the demo. You bring your director and one IT concern you want answered first.
          </p>
          <Link
            href="/schools/demo"
            className="inline-flex items-center gap-3 px-8 py-3.5 rounded-full bg-[#F5C96B] text-[#0B1E3F] font-semibold text-[15px] hover:bg-[#F7D688] transition-colors"
          >
            Request a pilot
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        </div>
      </section>
    </>
  );
}
