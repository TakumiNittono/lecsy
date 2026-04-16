import type { Metadata } from "next";
import PrintButton from "@/components/PrintButton";

export const metadata: Metadata = {
  title: "Lecsy for Schools — One-pager",
  description: "A single printable sheet: what Lecsy is, how it handles student data, and how the pilot works.",
  robots: { index: false, follow: false },
};

/**
 * Print-optimized leave-behind, US Letter, single page.
 * Use Chrome Print → "Save as PDF" to produce the final handout.
 *
 * Design constraints:
 *   - No chrome: header/footer of <SchoolsLayout> is hidden with `print:hidden`;
 *     but we also want screen-readable layout. So we render a clean document
 *     body and rely on `@page` + compact font sizes to fit.
 */
export default function OnePager() {
  const today = new Date().toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  return (
    <>
      <style>{`
        @page { size: Letter; margin: 0.55in; }
        @media print {
          html, body { background: #ffffff !important; }
          .print-container { box-shadow: none !important; border: none !important; padding: 0 !important; max-width: 100% !important; }
          .no-print { display: none !important; }
        }
      `}</style>

      <div className="bg-white print:bg-white min-h-screen print:min-h-0">
        <div className="print-container max-w-[7.4in] mx-auto my-8 print:my-0 px-10 py-10 print:p-0 bg-white">
          <div className="no-print mb-8 flex items-center justify-between text-xs">
            <span className="text-[#8A9BB5]">
              Print this page: <code className="font-mono text-[#4A5B74]">Cmd/Ctrl + P</code>
            </span>
            <PrintButton label="Save as PDF" />
          </div>

          {/* HEADER */}
          <header className="flex items-baseline justify-between border-b border-[#0B1E3F] pb-4 mb-8">
            <div>
              <div className="font-[family-name:var(--font-display)] text-3xl font-semibold text-[#0B1E3F] leading-none">
                lecsy
              </div>
              <div className="text-xs text-[#8A9BB5] mt-1 uppercase tracking-[0.18em]">
                for ESL & IEP classrooms
              </div>
            </div>
            <div className="text-right text-xs text-[#4A5B74]">
              {today}
              <br />
              lecsy.app/schools
            </div>
          </header>

          {/* HERO */}
          <section className="mb-8">
            <h1 className="font-[family-name:var(--font-display)] text-[32px] leading-[1.15] font-semibold text-[#0B1E3F] mb-3">
              Lecture transcription, built for the ESL classroom.
            </h1>
            <p className="text-[13px] text-[#4A5B74] leading-relaxed max-w-[5in]">
              Real-time bilingual captions. AI summaries in 12 languages. Program-wide admin
              dashboard. Audio that never touches our servers. Designed specifically for
              Intensive English Programs and community-college ESL departments.
            </p>
          </section>

          {/* THREE PILLARS */}
          <section className="grid grid-cols-3 gap-6 mb-8">
            {[
              {
                k: "01",
                t: "Deepgram multilingual, live",
                d: "Captions in 12 languages via Deepgram Nova-3, side-by-side, word-by-word.",
              },
              {
                k: "02",
                t: "Privacy by retention",
                d: "Audio streamed over TLS, transcribed, discarded. Only the text is persisted.",
              },
              {
                k: "03",
                t: "Printable receipts",
                d: "Every program metric exports to CSV and prints cleanly for accreditors.",
              },
            ].map((p) => (
              <div key={p.k}>
                <div className="text-[10px] font-mono tracking-widest text-[#8A9BB5] mb-1">{p.k}</div>
                <h3 className="font-[family-name:var(--font-display)] text-[15px] font-semibold text-[#0B1E3F] mb-1 leading-tight">
                  {p.t}
                </h3>
                <p className="text-[11px] text-[#4A5B74] leading-relaxed">{p.d}</p>
              </div>
            ))}
          </section>

          {/* SECURITY */}
          <section className="mb-7 border border-[#E5E1D8] bg-[#F7F5F1] rounded-lg px-5 py-4">
            <h2 className="font-[family-name:var(--font-display)] text-[14px] font-semibold text-[#0B1E3F] mb-3 uppercase tracking-wider">
              Security snapshot
            </h2>
            <div className="grid grid-cols-2 gap-x-6 gap-y-1.5 text-[11px] text-[#4A5B74]">
              {[
                ["Audio stored by lecsy", "No — discarded after transcription"],
                ["Data residency", "United States, AWS us-east-1"],
                ["Encryption", "TLS 1.2+ in transit, AES-256 at rest"],
                ["Subprocessors", "Deepgram · Supabase · OpenAI · Stripe"],
                ["FERPA", "Aligned; DPA + Addendum available"],
                ["Deletion SLA", "30 days from termination"],
              ].map(([k, v]) => (
                <div key={k}>
                  <strong className="text-[#0B1E3F]">{k}:</strong> {v}
                </div>
              ))}
            </div>
          </section>

          {/* PILOT */}
          <section className="mb-7">
            <h2 className="font-[family-name:var(--font-display)] text-[14px] font-semibold text-[#0B1E3F] mb-2 uppercase tracking-wider">
              The pilot — free through June 1, 2026
            </h2>
            <div className="grid grid-cols-2 gap-6 text-[11px] text-[#4A5B74]">
              <div>
                <div className="text-[10px] font-semibold uppercase text-[#8A9BB5] mb-1">Included</div>
                <ul className="space-y-0.5 leading-[1.45]">
                  <li>• Up to 250 student seats (UF) / 100 (Santa Fe)</li>
                  <li>• Real-time bilingual captions, 12 languages</li>
                  <li>• AI summaries + exam-prep generation</li>
                  <li>• Org admin dashboard with per-student usage</li>
                  <li>• CSV export of program metrics</li>
                  <li>• Founder support, on-campus visits</li>
                </ul>
              </div>
              <div>
                <div className="text-[10px] font-semibold uppercase text-[#8A9BB5] mb-1">Not included</div>
                <ul className="space-y-0.5 leading-[1.45]">
                  <li>• SAML / SSO (Q4 2026 roadmap)</li>
                  <li>• HIPAA BAA (not designed for PHI)</li>
                  <li>• On-premise deployment</li>
                  <li>• White-label / custom domain</li>
                </ul>
              </div>
            </div>
          </section>

          {/* FOUNDER + CTA */}
          <section className="border-t-2 border-[#0B1E3F] pt-4 flex items-end justify-between gap-8">
            <div className="max-w-[3.6in]">
              <p className="text-[10px] font-semibold uppercase text-[#8A9BB5] tracking-wider mb-1">
                Founder-led
              </p>
              <p className="text-[11px] text-[#4A5B74] leading-relaxed">
                <strong className="text-[#0B1E3F]">Takumi Nittono</strong>, Gainesville FL. Built after
                watching international students fall behind in fast-talking lectures.
                <br />
                <span className="text-[#8A9BB5]">founder@lecsy.app</span>
              </p>
            </div>
            <div className="text-right">
              <div className="text-[10px] font-semibold uppercase text-[#8A9BB5] tracking-wider mb-1">
                Request a pilot
              </div>
              <div className="font-[family-name:var(--font-display)] text-[18px] font-semibold text-[#0B1E3F] leading-tight">
                lecsy.app/schools/demo
              </div>
              <div className="text-[11px] text-[#4A5B74] mt-1">
                15 minutes, on campus. We drive to you.
              </div>
            </div>
          </section>
        </div>
      </div>
    </>
  );
}
