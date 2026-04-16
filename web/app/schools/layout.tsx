import Link from "next/link";
import { Fraunces, Inter } from "next/font/google";
import type { Metadata } from "next";

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-display",
  display: "swap",
});

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-body",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "Lecsy for Schools | Lecture Transcription for ESL & IEP Programs",
    template: "%s | Lecsy for Schools",
  },
  description:
    "Real-time bilingual lecture transcription for ESL and IEP programs. Audio never stored. FERPA-aligned. Free pilot through June 1, 2026 for UF ELI and Santa Fe College.",
  alternates: { canonical: "https://www.lecsy.app/schools" },
  openGraph: {
    title: "Lecsy for Schools",
    description:
      "Real-time bilingual lecture transcription for ESL and IEP programs. Audio never stored. FERPA-aligned.",
    url: "https://www.lecsy.app/schools",
    type: "website",
  },
};

export default function SchoolsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className={`${fraunces.variable} ${inter.variable} min-h-screen bg-[#F7F5F1] text-[#0B1E3F]`}>
      <header className="sticky top-0 z-50 border-b border-[#E5E1D8] bg-[#F7F5F1]/90 backdrop-blur-md print:hidden">
        <div className="max-w-6xl mx-auto px-5 h-16 flex items-center justify-between">
          <Link
            href="/schools"
            className="flex items-baseline gap-2 font-[family-name:var(--font-display)]"
          >
            <span className="text-2xl font-semibold tracking-tight text-[#0B1E3F]">lecsy</span>
            <span className="text-sm text-[#8A9BB5] tracking-wide">for Schools</span>
          </Link>

          <nav className="hidden md:flex items-center gap-8 text-sm text-[#4A5B74]">
            <Link href="/schools" className="hover:text-[#0B1E3F] transition-colors">Overview</Link>
            <Link href="/schools/security" className="hover:text-[#0B1E3F] transition-colors">Security</Link>
            <Link href="/schools/pilot" className="hover:text-[#0B1E3F] transition-colors">Pilot</Link>
          </nav>

          <Link
            href="/schools/demo"
            className="h-9 px-4 flex items-center gap-2 rounded-full bg-[#0B1E3F] text-white text-sm font-medium hover:bg-[#16315C] transition-colors"
          >
            Request a pilot
          </Link>
        </div>
      </header>

      <main className="font-[family-name:var(--font-body)]">{children}</main>

      <footer className="border-t border-[#E5E1D8] bg-[#EFEBE3] print:hidden">
        <div className="max-w-6xl mx-auto px-5 py-12 grid md:grid-cols-4 gap-8 text-sm">
          <div>
            <div className="font-[family-name:var(--font-display)] text-xl font-semibold text-[#0B1E3F] mb-2">
              lecsy
            </div>
            <p className="text-[#4A5B74] leading-relaxed">
              Lecture transcription built for ESL and IEP classrooms. Privacy-first by design.
            </p>
            <p className="text-[#8A9BB5] text-xs mt-4">
              Gainesville, Florida · founder@lecsy.app
            </p>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#8A9BB5] mb-3">For Schools</h4>
            <ul className="space-y-2 text-[#4A5B74]">
              <li><Link href="/schools" className="hover:text-[#0B1E3F]">Overview</Link></li>
              <li><Link href="/schools/security" className="hover:text-[#0B1E3F]">Security & FERPA</Link></li>
              <li><Link href="/schools/pilot" className="hover:text-[#0B1E3F]">Pilot program</Link></li>
              <li><Link href="/schools/demo" className="hover:text-[#0B1E3F]">Request a pilot</Link></li>
              <li><Link href="/schools/one-pager" className="hover:text-[#0B1E3F]">Printable one-pager</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#8A9BB5] mb-3">For Students</h4>
            <ul className="space-y-2 text-[#4A5B74]">
              <li><Link href="/" className="hover:text-[#0B1E3F]">Student app</Link></li>
              <li><Link href="/privacy" className="hover:text-[#0B1E3F]">Privacy Policy</Link></li>
              <li><Link href="/terms" className="hover:text-[#0B1E3F]">Terms of Service</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#8A9BB5] mb-3">Contact</h4>
            <ul className="space-y-2 text-[#4A5B74]">
              <li>
                <a href="mailto:founder@lecsy.app" className="hover:text-[#0B1E3F]">founder@lecsy.app</a>
              </li>
              <li>
                <a href="mailto:founder@lecsy.app?subject=DPA%20request" className="hover:text-[#0B1E3F]">
                  Request DPA
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div className="border-t border-[#E5E1D8]">
          <div className="max-w-6xl mx-auto px-5 py-6 text-xs text-[#8A9BB5]">
            © {new Date().getFullYear()} Lecsy. Founder-led, Gainesville FL.
          </div>
        </div>
      </footer>
    </div>
  );
}
