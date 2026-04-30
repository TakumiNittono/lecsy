import type { Metadata, Viewport } from 'next';

export const metadata: Metadata = {
  title: 'Hospital Live Interpreter',
  description:
    '病院での英語→日本語リアルタイム通訳と、日本語質問の英訳。会話補助のためのツール。音声は保存されません。',
  manifest: '/k/manifest.webmanifest',
  robots: { index: false, follow: false },
  alternates: { canonical: 'https://www.lecsy.app/k' },
  appleWebApp: {
    capable: true,
    title: 'Interpreter',
    statusBarStyle: 'black-translucent',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  themeColor: '#0f172a',
};

export default function KLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen bg-slate-950 text-slate-100">{children}</div>;
}
