import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Free pilot program for ESL and IEP departments",
  description:
    "Through June 1, 2026, Lecsy is free for UF ELI and Santa Fe College ESL. Full scope, timeline, success metrics, and protocol.",
  alternates: { canonical: "https://www.lecsy.app/schools/pilot" },
};

export default function PilotPage() {
  return (
    <div className="max-w-3xl mx-auto px-5 py-20 lg:py-28">
      <Link
        href="/schools"
        className="inline-flex items-center gap-2 text-sm text-[#8A9BB5] hover:text-[#0B1E3F] mb-8"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to overview
      </Link>

      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
        Pilot program
      </p>
      <h1 className="font-[family-name:var(--font-display)] text-4xl md:text-5xl lg:text-6xl font-semibold leading-[1.05] tracking-tight text-[#0B1E3F] mb-6">
        Free through June 1, 2026.
      </h1>
      <p className="text-lg text-[#4A5B74] leading-relaxed mb-14 max-w-2xl">
        This pilot is a beta-testing collaboration — no fee, no contract to purchase, no obligation
        after. Two schools only, Gainesville-local: University of Florida ELI and Santa Fe College ESL.
      </p>

      {/* TIMELINE */}
      <section className="mb-16">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-8">
          Timeline
        </h2>
        <ol className="relative border-l-2 border-[#E5E1D8] pl-8 space-y-10">
          {[
            {
              t: "Week 0 — Kickoff",
              d: "15-minute on-campus demo with the director and one IT contact. We bring an iPhone and a live demo in English + the native language of your largest student population.",
            },
            {
              t: "Week 0–1 — Setup",
              d: "Your program gets a dedicated admin dashboard at lecsy.app/org/[your-school]. We preload your seat count, your approved email domain, and your timezone. We hand over owner access during the meeting.",
            },
            {
              t: "Week 1–6 — Active pilot",
              d: "Students download the iPhone app and use it in their actual classes. Admin sees usage metrics in real time. Founder checks in weekly by email; on-campus support available within 48 hours of any request.",
            },
            {
              t: "Week 6 — Checkpoint",
              d: "We look at the numbers together: weekly active students, minutes transcribed, AI summaries generated, and qualitative feedback from 3–5 students you select.",
            },
            {
              t: "2026-06-01 — End of free pilot",
              d: "If the program worked, we put together a proposal that fits your budget cycle. If it didn't, we walk away — you keep the data exports and we leave no residue on your network.",
            },
          ].map((step, i) => (
            <li key={step.t} className="relative">
              <span className="absolute -left-[41px] top-1 w-5 h-5 rounded-full bg-[#0B1E3F] text-[#F5C96B] text-xs font-semibold flex items-center justify-center">
                {i + 1}
              </span>
              <h3 className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-2">
                {step.t}
              </h3>
              <p className="text-[#4A5B74] leading-relaxed">{step.d}</p>
            </li>
          ))}
        </ol>
      </section>

      {/* SCOPE */}
      <section className="mb-16">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-8">
          Scope
        </h2>

        <div className="grid md:grid-cols-2 gap-8">
          <div>
            <h3 className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-4">
              Included
            </h3>
            <ul className="space-y-3 text-[#4A5B74] text-[15px]">
              {[
                "Student iPhone app (iOS 17.6+), unlimited recordings",
                "Real-time bilingual captions via Deepgram (12 languages)",
                "AI summaries and exam-prep generation",
                "Organization admin dashboard with per-student usage",
                "CSV export of program-wide metrics",
                "Printable onboarding guide for your team",
                "Founder email support + on-campus visits",
              ].map((s) => (
                <li key={s} className="flex gap-3">
                  <svg className="w-5 h-5 text-[#0B1E3F] flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>{s}</span>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3 className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-4">
              Not included
            </h3>
            <ul className="space-y-3 text-[#8A9BB5] text-[15px]">
              {[
                "SAML / SSO (Q4 2026 roadmap)",
                "SCIM provisioning",
                "HIPAA BAA — service not designed for PHI",
                "On-premise deployment",
                "White-label / custom domain",
                "24/7 pager support (best-effort founder response within 24h)",
              ].map((s) => (
                <li key={s} className="flex gap-3">
                  <svg className="w-5 h-5 text-[#C8C3B8] flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  <span>{s}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* SUCCESS METRICS */}
      <section className="mb-16">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-3">
          How we&apos;ll know it worked.
        </h2>
        <p className="text-[#4A5B74] mb-6 max-w-2xl">
          No pilot is a success by default. At Week 6 we look at three numbers together and make a
          judgment call — not a default-renew.
        </p>
        <div className="grid sm:grid-cols-3 gap-4">
          {[
            { k: "WAU", v: "≥ 40% of seats", l: "Weekly active students" },
            { k: "Minutes/week", v: "≥ 30 min per active student", l: "Actual usage, not trial" },
            { k: "Director NPS", v: "≥ 8/10", l: "Would you recommend to peer programs?" },
          ].map((m) => (
            <div key={m.k} className="rounded-2xl border border-[#E5E1D8] bg-white p-5">
              <div className="text-xs uppercase tracking-wider text-[#8A9BB5] mb-1">{m.k}</div>
              <div className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-1">
                {m.v}
              </div>
              <div className="text-xs text-[#4A5B74]">{m.l}</div>
            </div>
          ))}
        </div>
      </section>

      {/* PROTOCOL */}
      <section className="mb-16">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-6">
          Protocol
        </h2>
        <p className="text-[#4A5B74] leading-relaxed mb-4">
          The pilot runs under a one-page Beta Testing Protocol Agreement — a collaboration document,
          not a purchase contract. Key terms:
        </p>
        <ul className="space-y-3 text-[#4A5B74]">
          {[
            "No fee, no gift, no consideration of any kind exchanges hands.",
            "This is a research-and-feedback collaboration, not a commercial subscription.",
            "The institution retains ownership of all data entered during the pilot.",
            "Either party may terminate at any time via email with no financial consequences.",
            "Post-pilot, the institution is under no obligation to purchase or continue use.",
            "Audio is never stored by Lecsy. Transcript text is encrypted at rest and deletable.",
          ].map((s) => (
            <li key={s} className="flex gap-3">
              <svg className="w-4 h-4 text-[#0B1E3F] flex-shrink-0 mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span className="leading-relaxed">{s}</span>
            </li>
          ))}
        </ul>
        <p className="mt-6 text-sm text-[#8A9BB5]">
          Full Protocol Agreement sent by email when you request the pilot.
        </p>
      </section>

      {/* POST-PILOT */}
      <section className="mb-16 bg-[#F7F5F1] border border-[#E5E1D8] rounded-3xl p-8 md:p-10">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-4">
          After June 1, 2026.
        </h2>
        <p className="text-[#4A5B74] leading-relaxed mb-3">
          If the pilot succeeds, we&apos;ll put together a proposal individually. Seat count, contract
          term, and payment method (P-card, PO, or invoice) are all on the table. We build around your
          budget cycle, not ours.
        </p>
        <p className="text-[#4A5B74] leading-relaxed">
          If it doesn&apos;t succeed, your data export lands in your inbox and we disappear from your
          inbox. No auto-renew, no surprise invoice, no residue.
        </p>
      </section>

      {/* CTA */}
      <div className="flex flex-col sm:flex-row gap-3">
        <Link
          href="/schools/demo"
          className="inline-flex items-center justify-center gap-2 h-12 px-6 rounded-full bg-[#0B1E3F] text-white font-semibold text-[15px] hover:bg-[#16315C] transition-colors"
        >
          Request a pilot
        </Link>
        <Link
          href="/schools/security"
          className="inline-flex items-center justify-center gap-2 h-12 px-6 rounded-full border border-[#0B1E3F]/20 text-[#0B1E3F] font-medium text-[15px] hover:bg-white transition-colors"
        >
          Security & FERPA posture
        </Link>
      </div>
    </div>
  );
}
