// Picks the best supported MediaRecorder mimeType for our pipeline.
// Deepgram accepts opus in webm/ogg containers; mp4/aac is the fallback for
// browsers (Safari) that won't expose opus.

const CANDIDATES = [
  "audio/webm;codecs=opus",
  "audio/webm",
  "audio/ogg;codecs=opus",
  "audio/mp4",
] as const

export function pickMimeType(): string {
  if (typeof MediaRecorder === "undefined") return "audio/webm"
  for (const m of CANDIDATES) {
    try {
      if (MediaRecorder.isTypeSupported(m)) return m
    } catch {
      // ignore
    }
  }
  return "audio/webm"
}

export async function getMicStream(): Promise<MediaStream> {
  return navigator.mediaDevices.getUserMedia({
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      channelCount: 1,
    },
  })
}
