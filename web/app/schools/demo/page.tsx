import Link from "next/link";
import type { Metadata } from "next";
import DemoRequestForm from "./DemoRequestForm";

export const metadata: Metadata = {
  title: "Request a pilot",
  description:
    "Request a 15-minute on-campus demo. Free pilot through June 1, 2026 for UF ELI and Santa Fe College ESL.",
  alternates: { canonical: "https://www.lecsy.app/schools/demo" },
};

export default function DemoPage({
  searchParams,
}: {
  searchParams: { sent?: string };
}) {
  if (searchParams?.sent === "1") {
    return (
      <div className="max-w-2xl mx-auto px-5 py-24 lg:py-32 text-center">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-[#0B1E3F] text-[#F5C96B] mb-6">
          <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
          </svg>
        </div>
        <h1 className="font-[family-name:var(--font-display)] text-3xl md:text-5xl font-semibold tracking-tight text-[#0B1E3F] mb-4">
          Thank you — we&apos;ll reply within one business day.
        </h1>
        <p className="text-[#4A5B74] text-lg mb-10 leading-relaxed">
          Your request landed in founder@lecsy.app. Expect a short email proposing three on-campus
          times. If your question is urgent, reply to that email and we&apos;ll find time today.
        </p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link
            href="/schools/security"
            className="inline-flex items-center justify-center gap-2 h-11 px-5 rounded-full bg-[#0B1E3F] text-white font-medium text-[14px] hover:bg-[#16315C] transition-colors"
          >
            Read security posture
          </Link>
          <Link
            href="/schools/pilot"
            className="inline-flex items-center justify-center gap-2 h-11 px-5 rounded-full border border-[#0B1E3F]/20 text-[#0B1E3F] font-medium text-[14px] hover:bg-white transition-colors"
          >
            Read pilot terms
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-5 py-20 lg:py-28">
      <Link
        href="/schools"
        className="inline-flex items-center gap-2 text-sm text-[#8A9BB5] hover:text-[#0B1E3F] mb-8"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to overview
      </Link>

      <div className="grid lg:grid-cols-[1.1fr_1fr] gap-14">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
            Request a pilot
          </p>
          <h1 className="font-[family-name:var(--font-display)] text-4xl md:text-5xl lg:text-6xl font-semibold leading-[1.05] tracking-tight text-[#0B1E3F] mb-6">
            15 minutes, on campus.
          </h1>
          <p className="text-lg text-[#4A5B74] leading-relaxed mb-10 max-w-lg">
            Send this form and we&apos;ll email three times this week. We&apos;ll drive to you with an
            iPhone and a live demo in English plus the native language of your largest student
            population.
          </p>

          <div className="space-y-5 border-l-2 border-[#E5E1D8] pl-6">
            {[
              { t: "One business day", d: "Reply from founder@lecsy.app." },
              { t: "Free through 2026-06-01", d: "No payment discussion until you ask for one." },
              { t: "No IT checklist first", d: "Bring IT concerns to the demo; we answer live." },
            ].map((p) => (
              <div key={p.t}>
                <h3 className="font-semibold text-[#0B1E3F]">{p.t}</h3>
                <p className="text-sm text-[#4A5B74]">{p.d}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white border border-[#E5E1D8] rounded-3xl p-8">
          <DemoRequestForm />
        </div>
      </div>
    </div>
  );
}
