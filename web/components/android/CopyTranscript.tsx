"use client"

import { useState } from "react"

export function CopyTranscript({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <button
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(text)
          setCopied(true)
          setTimeout(() => setCopied(false), 1500)
        } catch {
          /* ignore */
        }
      }}
      className="h-9 px-3 rounded-lg border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50"
    >
      {copied ? "Copied!" : "Copy"}
    </button>
  )
}
