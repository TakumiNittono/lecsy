"use client"

import { useEffect, useState } from "react"

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>
}

export function InstallPrompt() {
  const [evt, setEvt] = useState<BeforeInstallPromptEvent | null>(null)
  const [dismissed, setDismissed] = useState(false)
  const [installed, setInstalled] = useState(false)

  useEffect(() => {
    const isStandalone =
      typeof window !== "undefined" &&
      (window.matchMedia("(display-mode: standalone)").matches ||
        // @ts-expect-error iOS Safari
        window.navigator.standalone === true)
    setInstalled(isStandalone)

    const handler = (e: Event) => {
      e.preventDefault()
      setEvt(e as BeforeInstallPromptEvent)
    }
    window.addEventListener("beforeinstallprompt", handler)
    const installedHandler = () => setInstalled(true)
    window.addEventListener("appinstalled", installedHandler)
    return () => {
      window.removeEventListener("beforeinstallprompt", handler)
      window.removeEventListener("appinstalled", installedHandler)
    }
  }, [])

  if (installed || dismissed || !evt) return null

  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-4 flex items-center gap-3">
      <div className="flex-1">
        <p className="font-semibold text-gray-900 text-sm">Install Lecsy</p>
        <p className="text-xs text-gray-600">Add to home screen for fullscreen recording.</p>
      </div>
      <button
        onClick={async () => {
          try {
            await evt.prompt()
            const choice = await evt.userChoice
            if (choice.outcome !== "accepted") setDismissed(true)
            setEvt(null)
          } catch {
            setDismissed(true)
          }
        }}
        className="h-9 px-3 rounded-lg bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700"
      >
        Install
      </button>
      <button
        onClick={() => setDismissed(true)}
        aria-label="Dismiss"
        className="text-gray-400 hover:text-gray-700 text-xl leading-none"
      >
        ×
      </button>
    </div>
  )
}
