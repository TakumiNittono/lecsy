import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Lecsy | Lecture Recording & AI Transcription App for Students",
  description: "Lecsy is a lecture recording and AI transcription app designed for college and international students to better understand lectures.",
  alternates: {
    canonical: "https://www.lecsy.app/",
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
