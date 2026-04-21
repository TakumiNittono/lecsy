// Minimal browser client for Deepgram Live API.
// Token is fetched from the existing supabase edge function `deepgram-token`,
// which gates by plan / daily / monthly cap and returns a 15-min TTL key.

export type DeepgramSegment = {
  text: string
  isFinal: boolean
  confidence: number
  speaker?: number
  start: number
  end: number
}

export type DeepgramStream = {
  send: (chunk: Blob | ArrayBuffer) => void
  close: () => void
  readyState: () => number
}

type Options = {
  token: string
  language?: string
  mimeType: string
  onSegment: (seg: DeepgramSegment) => void
  onError?: (err: Event | Error) => void
  onClose?: () => void
}

export function openDeepgramStream(opts: Options): DeepgramStream {
  const params = new URLSearchParams({
    model: "nova-2-general",
    language: opts.language || "en-US",
    smart_format: "true",
    interim_results: "true",
    punctuate: "true",
    encoding: encodingFromMime(opts.mimeType),
    // Most browsers default opus webm streams. Don't force sample_rate
    // unless we know it; Deepgram infers it from container.
  })

  const url = `wss://api.deepgram.com/v1/listen?${params.toString()}`
  const ws = new WebSocket(url, ["token", opts.token])

  ws.onmessage = (e) => {
    try {
      const msg = JSON.parse(typeof e.data === "string" ? e.data : "")
      if (msg.type !== "Results") return
      const alt = msg.channel?.alternatives?.[0]
      if (!alt?.transcript) return
      opts.onSegment({
        text: alt.transcript,
        isFinal: !!msg.is_final,
        confidence: alt.confidence ?? 0,
        speaker: alt.words?.[0]?.speaker,
        start: msg.start ?? 0,
        end: (msg.start ?? 0) + (msg.duration ?? 0),
      })
    } catch {
      // ignore non-JSON keepalive frames
    }
  }
  ws.onerror = (e) => opts.onError?.(e)
  ws.onclose = () => opts.onClose?.()

  return {
    send: (chunk) => {
      if (ws.readyState !== WebSocket.OPEN) return
      ws.send(chunk as any)
    },
    close: () => {
      try {
        if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: "CloseStream" }))
      } catch {
        // ignore
      }
      try { ws.close() } catch { /* ignore */ }
    },
    readyState: () => ws.readyState,
  }
}

function encodingFromMime(mime: string): string {
  if (mime.includes("opus")) return "opus"
  if (mime.includes("webm")) return "opus"
  if (mime.includes("ogg")) return "opus"
  if (mime.includes("mp4")) return "mp4"
  return "opus"
}
