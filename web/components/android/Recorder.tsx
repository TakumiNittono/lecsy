"use client"

import { useEffect, useRef, useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/utils/supabase/client"
import { getMicStream, pickMimeType } from "@/lib/android/recorder"
import { openDeepgramStream, type DeepgramStream } from "@/lib/android/deepgram-stream"

type Status = "idle" | "starting" | "recording" | "stopping" | "saving" | "error"

type Segment = { id: number; text: string }

export function Recorder({ orgId }: { orgId: string }) {
  const router = useRouter()
  const [status, setStatus] = useState<Status>("idle")
  const [error, setError] = useState<string | null>(null)
  const [interim, setInterim] = useState("")
  const [finals, setFinals] = useState<Segment[]>([])
  const [seconds, setSeconds] = useState(0)

  const streamRef = useRef<MediaStream | null>(null)
  const recorderRef = useRef<MediaRecorder | null>(null)
  const dgRef = useRef<DeepgramStream | null>(null)
  const wakeLockRef = useRef<any>(null)
  const startMsRef = useRef<number>(0)
  const tickRef = useRef<number | null>(null)
  const finalsTextRef = useRef<string[]>([])
  const segIdRef = useRef(1)

  useEffect(() => {
    return () => {
      cleanup()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function cleanup() {
    try { recorderRef.current?.state !== "inactive" && recorderRef.current?.stop() } catch { /* ignore */ }
    try { streamRef.current?.getTracks().forEach((t) => t.stop()) } catch { /* ignore */ }
    try { dgRef.current?.close() } catch { /* ignore */ }
    try { wakeLockRef.current?.release?.() } catch { /* ignore */ }
    if (tickRef.current) {
      window.clearInterval(tickRef.current)
      tickRef.current = null
    }
    streamRef.current = null
    recorderRef.current = null
    dgRef.current = null
    wakeLockRef.current = null
  }

  async function start() {
    setError(null)
    setStatus("starting")
    setFinals([])
    setInterim("")
    finalsTextRef.current = []
    segIdRef.current = 1

    try {
      const supabase = createClient()
      const { data, error: fnErr } = await supabase.functions.invoke("deepgram-token", {
        body: {},
      })
      if (fnErr) throw new Error(fnErr.message || "deepgram-token failed")
      const tokenResp = (data ?? {}) as { token?: string; error?: string }
      if (!tokenResp.token) {
        throw new Error(humanizeTokenError(tokenResp.error))
      }

      const mic = await getMicStream()
      streamRef.current = mic

      const mime = pickMimeType()
      const rec = new MediaRecorder(mic, { mimeType: mime, audioBitsPerSecond: 32000 })
      recorderRef.current = rec

      const dg = openDeepgramStream({
        token: tokenResp.token,
        mimeType: mime,
        language: "en-US",
        onSegment: (seg) => {
          if (seg.isFinal) {
            const text = seg.text.trim()
            if (!text) return
            finalsTextRef.current.push(text)
            setFinals((prev) => [...prev, { id: segIdRef.current++, text }])
            setInterim("")
          } else {
            setInterim(seg.text)
          }
        },
        onError: () => {
          // Deepgram closes connection on token expiry — we'll surface in stop()
        },
      })
      dgRef.current = dg

      rec.ondataavailable = (e) => {
        if (e.data && e.data.size > 0) dg.send(e.data)
      }
      rec.start(250) // emit 250ms chunks for low latency captions

      try {
        wakeLockRef.current = await (navigator as any).wakeLock?.request?.("screen")
      } catch {
        // non-fatal
      }

      startMsRef.current = Date.now()
      tickRef.current = window.setInterval(() => {
        setSeconds(Math.floor((Date.now() - startMsRef.current) / 1000))
      }, 500)

      setStatus("recording")
    } catch (e: any) {
      cleanup()
      setStatus("error")
      setError(e?.message || "Couldn't start recording")
    }
  }

  async function stop() {
    if (status !== "recording") return
    setStatus("stopping")

    try {
      // Drain any in-flight final segments by giving the WS a moment.
      await new Promise<void>((resolve) => {
        const rec = recorderRef.current
        if (!rec || rec.state === "inactive") { resolve(); return }
        const onStop = () => { rec.removeEventListener("stop", onStop); resolve() }
        rec.addEventListener("stop", onStop)
        try { rec.stop() } catch { resolve() }
      })
      await new Promise((r) => setTimeout(r, 600))

      try { dgRef.current?.close() } catch { /* ignore */ }
      try { streamRef.current?.getTracks().forEach((t) => t.stop()) } catch { /* ignore */ }
      try { wakeLockRef.current?.release?.() } catch { /* ignore */ }
      if (tickRef.current) { window.clearInterval(tickRef.current); tickRef.current = null }

      const content = finalsTextRef.current.join(" ").trim()
      const duration = Math.round((Date.now() - startMsRef.current) / 1000)

      if (!content) {
        setStatus("idle")
        setError("No speech was captured. Check your microphone and try again.")
        return
      }

      setStatus("saving")
      const supabase = createClient()
      const title = `Lecture ${new Date().toLocaleString()}`
      const { data: saved, error: saveErr } = await supabase.functions.invoke("save-transcript", {
        body: {
          title,
          content,
          created_at: new Date(startMsRef.current).toISOString(),
          duration,
          language: "en",
          app_version: "android-pwa",
          organization_id: orgId,
          visibility: "private",
        },
      })
      if (saveErr) throw new Error(saveErr.message || "save failed")
      const id = (saved as any)?.id
      if (id) router.replace(`/android/t/${id}`)
      else router.replace("/android/library")
    } catch (e: any) {
      setStatus("error")
      setError(e?.message || "Failed to save transcript")
    }
  }

  const mm = String(Math.floor(seconds / 60)).padStart(2, "0")
  const ss = String(seconds % 60).padStart(2, "0")

  return (
    <div className="min-h-screen flex flex-col bg-gray-950 text-white">
      <header className="px-5 pt-6 pb-3 flex items-center justify-between">
        <button
          onClick={() => { cleanup(); router.replace("/android/app") }}
          className="text-gray-400 text-sm"
          disabled={status === "recording" || status === "saving" || status === "stopping"}
        >
          ← Cancel
        </button>
        <div className="flex items-center gap-2">
          <span className={`w-2 h-2 rounded-full ${status === "recording" ? "bg-red-500 animate-pulse" : "bg-gray-600"}`} />
          <span className="text-xs text-gray-400 uppercase tracking-wider">
            {status === "recording" ? "Live" : status === "starting" ? "Starting" : status === "saving" ? "Saving" : status === "stopping" ? "Stopping" : status === "error" ? "Error" : "Ready"}
          </span>
        </div>
      </header>

      <div className="text-center px-5 pt-6">
        <p className="text-6xl font-mono font-bold tabular-nums">{mm}:{ss}</p>
        <p className="mt-2 text-xs text-gray-500">
          Keep this screen on for best results.
        </p>
      </div>

      <main className="flex-1 px-5 mt-6 mb-32 overflow-y-auto">
        <div className="space-y-3 text-lg leading-relaxed">
          {finals.map((s) => (
            <p key={s.id} className="text-white">{s.text}</p>
          ))}
          {interim && (
            <p className="text-gray-400 italic">{interim}</p>
          )}
          {finals.length === 0 && !interim && status === "recording" && (
            <p className="text-gray-500 text-sm">Listening…</p>
          )}
        </div>

        {error && (
          <div className="mt-6 p-3 rounded-xl bg-red-900/40 border border-red-700 text-sm text-red-200">
            {error}
          </div>
        )}
      </main>

      <div className="fixed bottom-0 inset-x-0 px-5 pb-8 pt-4 bg-gradient-to-t from-gray-950 via-gray-950 to-transparent">
        {status === "recording" ? (
          <button
            onClick={stop}
            className="mx-auto block w-20 h-20 rounded-full bg-red-600 active:scale-95 transition-transform shadow-lg shadow-red-900/40"
            aria-label="Stop recording"
          >
            <span className="block w-6 h-6 mx-auto rounded-sm bg-white" />
          </button>
        ) : status === "starting" || status === "saving" || status === "stopping" ? (
          <div className="mx-auto block w-20 h-20 rounded-full bg-gray-700 animate-pulse" />
        ) : (
          <button
            onClick={start}
            className="mx-auto block w-20 h-20 rounded-full bg-red-600 active:scale-95 transition-transform shadow-lg shadow-red-900/40"
            aria-label="Start recording"
          >
            <span className="block w-12 h-12 mx-auto rounded-full bg-white" />
          </button>
        )}
      </div>
    </div>
  )
}

function humanizeTokenError(code?: string): string {
  switch (code) {
    case "feature_disabled": return "Real-time captions are not enabled for your account yet."
    case "budget_exceeded":  return "Live captions are temporarily paused. Please try again later."
    case "daily_cap":        return "You've hit today's recording limit. Try again tomorrow."
    case "monthly_cap":      return "You've hit this month's recording limit."
    case "unauthorized":     return "Your session has expired. Please open the app again."
    default:                 return code ? `Couldn't start: ${code}` : "Couldn't get a microphone token."
  }
}
