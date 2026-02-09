import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL('https://www.lecsy.app'),
  title: {
    default: "Lecsy | Lecture Recording & AI Transcription App for Students",
    template: "%s | Lecsy",
  },
  description: "Record college lectures on your iPhone, transcribe with AI offline, and review anytime. Built for international and college students who want to truly understand every lecture.",
  keywords: [
    "lecture recording app",
    "ai transcription for students",
    "college lecture recorder",
    "international students lecture app",
    "ai note taking",
    "lecture transcription",
    "offline transcription app",
    "otter alternative",
    "lecture recording app college",
    "ai transcription app college",
  ],
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://www.lecsy.app/',
    siteName: 'Lecsy',
    title: 'Lecsy – Lecture Recording & AI Transcription for Students',
    description: 'Record college lectures, transcribe with AI, and review anytime. Free for students.',
    images: [
      {
        url: '/og-image.jpg',
        width: 1200,
        height: 630,
        alt: 'Lecsy - Lecture Recording & AI Transcription App',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Lecsy – Lecture Recording & AI Transcription for Students',
    description: 'Record college lectures, transcribe with AI, and review anytime. Free for students.',
    images: ['/og-image.jpg'],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: [
      { url: "/icon.png", type: "image/png" },
    ],
    apple: [
      { url: "/apple-icon.png", type: "image/png" },
    ],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
