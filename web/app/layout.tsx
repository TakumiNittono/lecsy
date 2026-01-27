import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "lecsy — Turn lectures into understanding",
  description: "Record lectures on iPhone. Read anywhere. Let AI do the rest.",
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
