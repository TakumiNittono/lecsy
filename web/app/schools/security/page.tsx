import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Security & FERPA posture",
  description:
    "How Lecsy protects student data — audio never stored, FERPA-aligned retention, encryption in transit and at rest, and subprocessor transparency.",
  alternates: { canonical: "https://www.lecsy.app/schools/security" },
};

export default function SecurityPage() {
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

      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#8A9BB5] mb-4">
        Security & compliance
      </p>
      <h1 className="font-[family-name:var(--font-display)] text-4xl md:text-5xl lg:text-6xl font-semibold leading-[1.05] tracking-tight text-[#0B1E3F] mb-8">
        Security posture, written plainly.
      </h1>
      <p className="text-lg text-[#4A5B74] leading-relaxed max-w-3xl mb-16">
        This page is the short version of the HECVAT Lite answers your IT department will ask for.
        The full document is available on request. Everything on this page is committed — if we
        change it, we&apos;ll email you 30 days ahead.
      </p>

      {/* DATA FLOW */}
      <section className="mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-6">
          How student data moves through the system.
        </h2>

        <div className="bg-white border border-[#E5E1D8] rounded-2xl p-6 md:p-10">
          {/* Inline SVG data flow */}
          <svg
            viewBox="0 0 680 260"
            className="w-full h-auto"
            aria-label="Data flow: iPhone → Deepgram (transcribe, discard audio) → Supabase Postgres (text only) → Lecsy dashboard"
          >
            <defs>
              <marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto">
                <path d="M0,0 L10,5 L0,10 z" fill="#4A5B74" />
              </marker>
            </defs>

            {/* iPhone */}
            <g>
              <rect x="20" y="90" width="120" height="80" rx="12" fill="#0B1E3F" />
              <text x="80" y="125" textAnchor="middle" fill="#F5C96B" fontSize="13" fontFamily="system-ui" fontWeight="600">
                Student iPhone
              </text>
              <text x="80" y="145" textAnchor="middle" fill="#C8D1E0" fontSize="11" fontFamily="system-ui">
                audio capture
              </text>
            </g>
            <text x="80" y="195" textAnchor="middle" fill="#8A9BB5" fontSize="10" fontFamily="system-ui">
              .m4a stays local
            </text>

            {/* Arrow 1 */}
            <line x1="145" y1="130" x2="215" y2="130" stroke="#4A5B74" strokeWidth="1.5" markerEnd="url(#arrow)" />
            <text x="180" y="120" textAnchor="middle" fill="#4A5B74" fontSize="10" fontFamily="system-ui">
              TLS 1.2+
            </text>

            {/* Deepgram */}
            <g>
              <rect x="220" y="90" width="140" height="80" rx="12" fill="#FFFFFF" stroke="#E5E1D8" strokeWidth="1.5" />
              <text x="290" y="120" textAnchor="middle" fill="#0B1E3F" fontSize="13" fontFamily="system-ui" fontWeight="600">
                Deepgram
              </text>
              <text x="290" y="140" textAnchor="middle" fill="#4A5B74" fontSize="11" fontFamily="system-ui">
                transcribe
              </text>
              <text x="290" y="156" textAnchor="middle" fill="#B03A2E" fontSize="10" fontFamily="system-ui" fontWeight="600">
                audio discarded
              </text>
            </g>
            <text x="290" y="200" textAnchor="middle" fill="#8A9BB5" fontSize="10" fontFamily="system-ui">
              SOC 2 Type II · US
            </text>

            {/* Arrow 2 */}
            <line x1="365" y1="130" x2="435" y2="130" stroke="#4A5B74" strokeWidth="1.5" markerEnd="url(#arrow)" />
            <text x="400" y="120" textAnchor="middle" fill="#4A5B74" fontSize="10" fontFamily="system-ui">
              text only
            </text>

            {/* Supabase */}
            <g>
              <rect x="440" y="90" width="140" height="80" rx="12" fill="#FFFFFF" stroke="#E5E1D8" strokeWidth="1.5" />
              <text x="510" y="120" textAnchor="middle" fill="#0B1E3F" fontSize="13" fontFamily="system-ui" fontWeight="600">
                Supabase Postgres
              </text>
              <text x="510" y="140" textAnchor="middle" fill="#4A5B74" fontSize="11" fontFamily="system-ui">
                text, AES-256
              </text>
              <text x="510" y="156" textAnchor="middle" fill="#4A5B74" fontSize="10" fontFamily="system-ui">
                RLS, org-scoped
              </text>
            </g>
            <text x="510" y="200" textAnchor="middle" fill="#8A9BB5" fontSize="10" fontFamily="system-ui">
              AWS us-east-1
            </text>

            {/* Arrow to admin */}
            <line x1="510" y1="170" x2="510" y2="225" stroke="#4A5B74" strokeWidth="1.5" markerEnd="url(#arrow)" />
            <text x="610" y="232" textAnchor="middle" fill="#4A5B74" fontSize="11" fontFamily="system-ui" fontWeight="600">
              Program admin dashboard
            </text>
          </svg>

          <p className="text-sm text-[#4A5B74] mt-6 max-w-2xl">
            The audio file is never uploaded to Lecsy. It is streamed to Deepgram over an encrypted
            connection for real-time transcription and discarded in memory. Only the resulting text,
            scoped to your organization via row-level security, is persisted.
          </p>
        </div>
      </section>

      {/* KEY FACTS */}
      <section className="mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-8">
          The HECVAT Lite answers in 10 lines.
        </h2>

        <div className="space-y-0 border-t border-[#E5E1D8]">
          {[
            ["What data is collected?", "Authentication (email), usage (minutes, language), and transcript text. No recorded audio."],
            ["Is audio stored?", "No. Streamed to Deepgram for real-time transcription and immediately discarded."],
            ["Data classification", "FERPA-relevant (education records). Not HIPAA. PCI handled entirely by Stripe (PCI Level 1)."],
            ["Data residency", "United States — AWS us-east-1, via Supabase."],
            ["Encryption in transit", "TLS 1.2+ enforced on all client–server and inter-service calls."],
            ["Encryption at rest", "AES-256, Supabase-managed keys (AWS KMS)."],
            ["Data retention (text)", "Indefinite until user or org deletion. Usage logs retained 90 days."],
            ["Data retention (audio)", "Never stored. There is no audio retention policy because there is no audio to retain."],
            ["Deletion SLA", "30 days for full production purge. 90 days for backup expiration."],
            ["Data export", "JSON, TXT, SRT, VTT, PDF exports available at any time to org admins."],
          ].map(([q, a]) => (
            <div key={q} className="grid md:grid-cols-[260px_1fr] gap-4 md:gap-8 py-5 border-b border-[#E5E1D8]">
              <dt className="font-medium text-[#0B1E3F]">{q}</dt>
              <dd className="text-[#4A5B74] leading-relaxed">{a}</dd>
            </div>
          ))}
        </div>
      </section>

      {/* SUBPROCESSORS */}
      <section className="mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-3">
          Subprocessors.
        </h2>
        <p className="text-[#4A5B74] mb-8 max-w-3xl">
          These are the only third parties that touch student data. We&apos;ll notify you 30 days
          before adding any new one.
        </p>

        <div className="overflow-x-auto rounded-2xl border border-[#E5E1D8] bg-white">
          <table className="w-full text-sm">
            <thead className="bg-[#F7F5F1]">
              <tr>
                <th className="text-left px-5 py-3 font-semibold text-[#0B1E3F]">Vendor</th>
                <th className="text-left px-5 py-3 font-semibold text-[#0B1E3F]">Role</th>
                <th className="text-left px-5 py-3 font-semibold text-[#0B1E3F]">Data handled</th>
                <th className="text-left px-5 py-3 font-semibold text-[#0B1E3F]">Certification</th>
              </tr>
            </thead>
            <tbody>
              {[
                { v: "Deepgram, Inc.", r: "Speech-to-text (real-time)", d: "Audio (discarded after transcription)", c: "SOC 2 Type II" },
                { v: "Supabase", r: "Database, auth, storage", d: "Transcript text, user accounts, org data", c: "SOC 2 Type II · built on AWS" },
                { v: "OpenAI", r: "AI summaries (optional)", d: "Transcript text only — never audio. Not used for training.", c: "SOC 2 Type II" },
                { v: "Stripe", r: "Payment processing (post-pilot)", d: "Billing contact, payment method", c: "PCI DSS Level 1 · SOC 2" },
              ].map((row) => (
                <tr key={row.v} className="border-t border-[#E5E1D8]">
                  <td className="px-5 py-4 font-medium text-[#0B1E3F] whitespace-nowrap">{row.v}</td>
                  <td className="px-5 py-4 text-[#4A5B74]">{row.r}</td>
                  <td className="px-5 py-4 text-[#4A5B74]">{row.d}</td>
                  <td className="px-5 py-4 text-[#4A5B74] whitespace-nowrap">{row.c}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* COMPLIANCE */}
      <section className="mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-8">
          Compliance posture.
        </h2>
        <div className="grid md:grid-cols-2 gap-6">
          {[
            { t: "FERPA", s: "Aligned by design", b: "Audio never stored. Text scoped to the organization. FERPA Addendum + DPA available on request." },
            { t: "COPPA", s: "Not directed at children under 13", b: "Signup age verification. Not marketed to K–12 under-13 audiences." },
            { t: "GDPR", s: "EU students supported via addendum", b: "DPA + Standard Contractual Clauses available." },
            { t: "CCPA / CPRA", s: "Honored", b: "Data export and deletion rights honored on request." },
            { t: "Section 508 / WCAG 2.1 AA", s: "Targeted", b: "VPAT 2.5 self-assessment available. Manual testing with VoiceOver + Dynamic Type." },
            { t: "SOC 2 Type II", s: "In preparation", b: "Target 2027-Q1. Today we ride on the SOC 2 of our subprocessors (Deepgram, Supabase, Stripe)." },
          ].map((c) => (
            <div key={c.t} className="border border-[#E5E1D8] rounded-2xl p-6 bg-white">
              <div className="flex items-baseline justify-between mb-2">
                <h3 className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F]">{c.t}</h3>
                <span className="text-xs font-semibold uppercase tracking-wider text-[#F5C96B] bg-[#0B1E3F] px-2 py-0.5 rounded">
                  {c.s}
                </span>
              </div>
              <p className="text-[#4A5B74] text-sm leading-relaxed">{c.b}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ACCESS */}
      <section className="mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-6">
          Access & accounts.
        </h2>
        <ul className="space-y-3 text-[#4A5B74]">
          {[
            "Authentication: email or Sign in with Apple. MFA available via Apple-side MFA.",
            "Role-based access: student / teacher / org admin / super admin, enforced in Postgres RLS.",
            "Account provisioning: manual email invite or CSV bulk import by org admins.",
            "Account deprovisioning: org admin deactivate; automatic purge 30 days after contract termination.",
            "Audit logging: retained 90 days, exportable.",
            "SAML SSO: planned for Q4 2026 at Enterprise tier.",
          ].map((s) => (
            <li key={s} className="flex gap-3">
              <svg className="w-5 h-5 text-[#0B1E3F] flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
              <span className="leading-relaxed">{s}</span>
            </li>
          ))}
        </ul>
      </section>

      {/* OPERATIONAL */}
      <section className="mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold text-[#0B1E3F] mb-6">
          Operations.
        </h2>
        <div className="grid md:grid-cols-2 gap-x-10 gap-y-5 text-[#4A5B74]">
          <div>
            <dt className="font-medium text-[#0B1E3F] mb-1">Vulnerability scanning</dt>
            <dd>Automated via GitHub Dependabot on every commit.</dd>
          </div>
          <div>
            <dt className="font-medium text-[#0B1E3F] mb-1">Patch management</dt>
            <dd>Critical 24h / High 7d / Medium 30d.</dd>
          </div>
          <div>
            <dt className="font-medium text-[#0B1E3F] mb-1">Backups</dt>
            <dd>Daily automated, 7-day point-in-time recovery, monthly snapshots retained 1 year.</dd>
          </div>
          <div>
            <dt className="font-medium text-[#0B1E3F] mb-1">Incident response</dt>
            <dd>Customer notification within 72 hours of confirmed breach.</dd>
          </div>
          <div>
            <dt className="font-medium text-[#0B1E3F] mb-1">RTO / RPO</dt>
            <dd>RTO 4 hours, RPO 24 hours (5 min for PITR-eligible).</dd>
          </div>
          <div>
            <dt className="font-medium text-[#0B1E3F] mb-1">Cyber insurance</dt>
            <dd>$1M Cyber Liability + E&amp;O planned prior to first paid contract.</dd>
          </div>
        </div>
      </section>

      {/* DPA */}
      <section className="bg-[#0B1E3F] text-white rounded-3xl px-8 md:px-12 py-12 mb-20">
        <h2 className="font-[family-name:var(--font-display)] text-2xl md:text-3xl font-semibold mb-4">
          Documents on request.
        </h2>
        <p className="text-[#C8D1E0] mb-8 max-w-2xl">
          DPA, FERPA Addendum, VPAT 2.5 self-assessment, and full HECVAT Lite response — email
          founder@lecsy.app and we&apos;ll send them within one business day.
        </p>
        <a
          href="mailto:founder@lecsy.app?subject=DPA%2FFERPA%20document%20request"
          className="inline-flex items-center gap-2 h-11 px-6 rounded-full bg-[#F5C96B] text-[#0B1E3F] font-semibold text-sm hover:bg-[#F7D688] transition-colors"
        >
          Email founder@lecsy.app
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
          </svg>
        </a>
      </section>

      <p className="text-xs text-[#8A9BB5]">
        Last updated: {new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}.
        This page summarizes our current security posture. The underlying HECVAT Lite answers are authoritative.
      </p>
    </div>
  );
}
