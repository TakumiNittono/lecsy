'use client'

import { useEffect, useRef, useState } from 'react'

const STORAGE_KEY = 'mp3:pin'
const EXPECTED_PIN = '0816'
const MAX_BYTES = 500 * 1024 * 1024 // 500MB (bucket file_size_limit と合わせる)

export default function Mp3Page() {
  const [unlocked, setUnlocked] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return
    if (sessionStorage.getItem(STORAGE_KEY) === EXPECTED_PIN) {
      setUnlocked(true)
    }
  }, [])

  if (!unlocked) {
    return (
      <LockScreen
        onUnlock={() => {
          sessionStorage.setItem(STORAGE_KEY, EXPECTED_PIN)
          setUnlocked(true)
        }}
      />
    )
  }

  return <Workspace />
}

function LockScreen({ onUnlock }: { onUnlock: () => void }) {
  const [value, setValue] = useState('')
  const [error, setError] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  function submit(v: string) {
    if (v === EXPECTED_PIN) {
      onUnlock()
    } else {
      setError(true)
      setTimeout(() => {
        setValue('')
        setError(false)
        inputRef.current?.focus()
      }, 700)
    }
  }

  return (
    <main className="min-h-screen bg-white flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-sm flex flex-col items-center">
        <div className="w-16 h-16 rounded-full bg-neutral-100 flex items-center justify-center mb-6">
          <svg className="w-7 h-7 text-neutral-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8}
              d="M12 11c1.1 0 2-.9 2-2V7a2 2 0 10-4 0v2c0 1.1.9 2 2 2zm6 0h-1V7a5 5 0 00-10 0v4H6a2 2 0 00-2 2v7a2 2 0 002 2h12a2 2 0 002-2v-7a2 2 0 00-2-2z" />
          </svg>
        </div>
        <h1 className="text-xl font-semibold text-neutral-900 tracking-tight">パスコードを入力</h1>
        <p className="text-sm text-neutral-500 mt-2">4桁の数字を入れてください</p>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            if (value.length === 4) submit(value)
          }}
          className={`mt-8 w-full ${error ? 'animate-shake' : ''}`}
        >
          <input
            ref={inputRef}
            type="password"
            inputMode="numeric"
            autoComplete="off"
            maxLength={4}
            value={value}
            onChange={(e) => {
              const v = e.target.value.replace(/\D/g, '').slice(0, 4)
              setValue(v)
              setError(false)
              if (v.length === 4) submit(v)
            }}
            className={`w-full text-center text-3xl tracking-[0.6em] py-4 rounded-2xl border ${
              error ? 'border-red-400 text-red-500' : 'border-neutral-300 text-neutral-900'
            } focus:outline-none focus:ring-2 focus:ring-neutral-900/30 bg-neutral-50`}
            aria-label="パスコード"
            autoFocus
          />
          <button
            type="submit"
            disabled={value.length !== 4}
            className="mt-4 w-full rounded-full bg-neutral-900 text-white text-base font-medium py-3 disabled:bg-neutral-300"
          >
            開く
          </button>
        </form>

        {error && (
          <p className="mt-4 text-sm text-red-600">パスコードが違います</p>
        )}
      </div>

      <style jsx>{`
        @keyframes shake {
          0%, 100% { transform: translateX(0); }
          20%, 60% { transform: translateX(-6px); }
          40%, 80% { transform: translateX(6px); }
        }
        .animate-shake { animation: shake 0.4s ease-in-out; }
      `}</style>
    </main>
  )
}

type Phase = 'idle' | 'uploading' | 'transcribing' | 'done' | 'error'

function Workspace() {
  const [file, setFile] = useState<File | null>(null)
  const [phase, setPhase] = useState<Phase>('idle')
  const [uploadPct, setUploadPct] = useState(0)
  const [transcribeElapsed, setTranscribeElapsed] = useState(0)
  const [transcript, setTranscript] = useState('')
  const [errorMsg, setErrorMsg] = useState('')
  const [copied, setCopied] = useState(false)
  const [dragging, setDragging] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [])

  async function handleTranscribe() {
    if (!file) return
    if (file.size > MAX_BYTES) {
      setErrorMsg(`ファイルが大きすぎます (上限 500MB)。現在 ${(file.size / (1024 * 1024)).toFixed(0)}MB`)
      setPhase('error')
      return
    }

    setErrorMsg('')
    setTranscript('')
    setUploadPct(0)
    setTranscribeElapsed(0)
    setPhase('uploading')

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    if (!supabaseUrl) {
      setErrorMsg('設定エラー: SUPABASE URL が未設定です。')
      setPhase('error')
      return
    }

    try {
      // 1) 署名付きアップロード URL を取得
      const signRes = await fetch(`${supabaseUrl}/functions/v1/mv3-sign-upload`, {
        method: 'POST',
        headers: {
          'x-mv3-pin': EXPECTED_PIN,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ filename: file.name }),
      })
      if (!signRes.ok) {
        const j = await signRes.json().catch(() => ({} as any))
        throw new Error(
          j?.error === 'unauthorized' ? 'パスコードが間違っています。' :
          j?.error || `アップロード準備に失敗しました (${signRes.status})`
        )
      }
      const { path, signedUrl } = await signRes.json()
      if (!path || !signedUrl) throw new Error('アップロード URL の取得に失敗しました。')

      // 2) ブラウザから Supabase Storage に直接 PUT (進捗表示)
      await new Promise<void>((resolve, reject) => {
        const xhr = new XMLHttpRequest()
        xhr.open('PUT', signedUrl)
        xhr.setRequestHeader('Content-Type', file.type || 'audio/mpeg')
        xhr.setRequestHeader('x-upsert', 'true')
        xhr.upload.onprogress = (ev) => {
          if (ev.lengthComputable) {
            setUploadPct(Math.round((ev.loaded / ev.total) * 100))
          }
        }
        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) resolve()
          else reject(new Error(`アップロードに失敗しました (${xhr.status})`))
        }
        xhr.onerror = () => reject(new Error('ネットワーク障害でアップロードできませんでした。'))
        xhr.send(file)
      })

      // 3) 文字起こし実行
      setPhase('transcribing')
      const start = Date.now()
      timerRef.current = setInterval(() => {
        setTranscribeElapsed(Math.floor((Date.now() - start) / 1000))
      }, 1000)

      const tRes = await fetch(`${supabaseUrl}/functions/v1/mv3-transcribe`, {
        method: 'POST',
        headers: {
          'x-mv3-pin': EXPECTED_PIN,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ path, language: 'ja' }),
      })
      if (timerRef.current) { clearInterval(timerRef.current); timerRef.current = null }

      if (!tRes.ok) {
        const j = await tRes.json().catch(() => ({} as any))
        throw new Error(
          j?.error === 'unauthorized' ? 'パスコードが間違っています。' :
          j?.error === 'deepgram_failed' ? `音声の処理に失敗しました (${j.status})。` :
          j?.error || `エラー (${tRes.status})`
        )
      }
      const tJson = await tRes.json()
      const text = (tJson?.transcript || '').trim()
      if (!text) {
        setErrorMsg('文字起こし結果が空でした。音声を確認してください。')
        setPhase('error')
        return
      }
      setTranscript(text)
      setPhase('done')
    } catch (e: any) {
      if (timerRef.current) { clearInterval(timerRef.current); timerRef.current = null }
      setErrorMsg(e?.message || '失敗しました')
      setPhase('error')
    }
  }

  async function handleCopy() {
    if (!transcript) return
    try {
      await navigator.clipboard.writeText(transcript)
      setCopied(true)
      setTimeout(() => setCopied(false), 1800)
    } catch {
      setErrorMsg('コピーに失敗しました。テキストを選択してコピーしてください。')
    }
  }

  function reset() {
    setFile(null)
    setTranscript('')
    setPhase('idle')
    setErrorMsg('')
    setUploadPct(0)
    setTranscribeElapsed(0)
    if (fileRef.current) fileRef.current.value = ''
  }

  function pickFile(f: File | null) {
    if (!f) return
    setFile(f)
    setErrorMsg('')
  }

  const busy = phase === 'uploading' || phase === 'transcribing'
  const elapsedLabel = `${Math.floor(transcribeElapsed / 60)}:${String(transcribeElapsed % 60).padStart(2, '0')}`

  return (
    <main className="min-h-screen bg-white">
      <div className="max-w-2xl mx-auto px-6 pt-16 pb-24">
        <header className="mb-10">
          <h1 className="text-3xl font-semibold text-neutral-900 tracking-tight">MP3 文字起こし</h1>
          <p className="mt-2 text-neutral-500 text-sm">
            MP3 ファイルを選んで「文字起こしをはじめる」を押してください。2時間の長い講義もそのまま入れて大丈夫です。
          </p>
        </header>

        {phase !== 'done' && (
          <section>
            <label
              htmlFor="mp3-file"
              onDragOver={(e) => { if (!busy) { e.preventDefault(); setDragging(true) } }}
              onDragLeave={() => setDragging(false)}
              onDrop={(e) => {
                if (busy) return
                e.preventDefault()
                setDragging(false)
                pickFile(e.dataTransfer.files?.[0] ?? null)
              }}
              className={`block w-full rounded-3xl border border-dashed transition-colors p-12 text-center ${
                busy ? 'border-neutral-200 bg-neutral-50 cursor-not-allowed' :
                dragging ? 'border-neutral-900 bg-neutral-100 cursor-pointer' :
                'border-neutral-300 bg-neutral-50 hover:bg-neutral-100 cursor-pointer'
              }`}
            >
              <div className="w-14 h-14 mx-auto rounded-full bg-white border border-neutral-200 flex items-center justify-center">
                <svg className="w-6 h-6 text-neutral-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8}
                    d="M9 19V6l12-3v13M9 19a3 3 0 11-6 0 3 3 0 016 0zm12-3a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </div>
              <p className="mt-4 text-neutral-900 font-medium">
                {file ? file.name : 'ここにドラッグ、またはクリックして MP3 を選ぶ'}
              </p>
              <p className="mt-1 text-xs text-neutral-500">
                {file ? `${(file.size / (1024 * 1024)).toFixed(1)} MB` : 'MP3 / M4A / WAV に対応 (最大 500MB)'}
              </p>
              <input
                id="mp3-file"
                ref={fileRef}
                type="file"
                accept="audio/mpeg,audio/mp3,audio/mp4,audio/m4a,audio/wav,audio/x-wav,.mp3,.m4a,.wav"
                className="hidden"
                disabled={busy}
                onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
              />
            </label>

            <button
              type="button"
              disabled={!file || busy}
              onClick={handleTranscribe}
              className="mt-6 w-full rounded-full bg-neutral-900 text-white text-base font-medium py-4 disabled:bg-neutral-300 transition-colors"
            >
              {phase === 'uploading' ? `アップロード中… ${uploadPct}%` :
               phase === 'transcribing' ? `文字起こし中… ${elapsedLabel}` :
               '文字起こしをはじめる'}
            </button>

            {phase === 'uploading' && (
              <div className="mt-4">
                <div className="h-1.5 w-full bg-neutral-200 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-neutral-900 transition-[width] duration-200"
                    style={{ width: `${uploadPct}%` }}
                  />
                </div>
                <p className="mt-3 text-center text-sm text-neutral-500">
                  ファイルを送っています…
                </p>
              </div>
            )}

            {phase === 'transcribing' && (
              <p className="mt-4 text-center text-sm text-neutral-500">
                いま文字に起こしています。2時間の音声だと数分かかります。このまま待っていてください。
              </p>
            )}

            {errorMsg && phase === 'error' && (
              <p className="mt-4 text-center text-sm text-red-600">{errorMsg}</p>
            )}
          </section>
        )}

        {phase === 'done' && (
          <section>
            <div className="rounded-3xl border border-neutral-200 bg-white p-5">
              <textarea
                readOnly
                value={transcript}
                className="w-full min-h-[40vh] resize-y bg-transparent text-neutral-900 leading-relaxed text-[16px] focus:outline-none"
                onFocus={(e) => e.currentTarget.select()}
              />
            </div>

            <div className="mt-6 flex gap-3">
              <button
                type="button"
                onClick={handleCopy}
                className="flex-1 rounded-full bg-neutral-900 text-white text-base font-medium py-4"
              >
                {copied ? 'コピーしました' : 'すべてコピー'}
              </button>
              <button
                type="button"
                onClick={reset}
                className="flex-1 rounded-full border border-neutral-300 bg-white text-neutral-900 text-base font-medium py-4"
              >
                別のファイルを選ぶ
              </button>
            </div>

            {errorMsg && (
              <p className="mt-4 text-center text-sm text-red-600">{errorMsg}</p>
            )}
          </section>
        )}
      </div>
    </main>
  )
}
