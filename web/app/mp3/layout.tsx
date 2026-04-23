import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'MP3 文字起こし',
  robots: { index: false, follow: false },
}

export default function Mp3Layout({ children }: { children: React.ReactNode }) {
  return children
}
