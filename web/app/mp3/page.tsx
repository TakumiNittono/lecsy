'use client'

import { useEffect, useRef, useState } from 'react'

const STORAGE_KEY = 'mp3:pin'
const EXPECTED_PIN = '0816'

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

type Status = 'idle' | 'uploading' | 'done' | 'error'

function Workspace() {
  const [file, setFile] = useState<File | null>(null)
  const [status, setStatus] = useState<Status>('idle')
  const [transcript, setTranscript] = useState('')
  const [errorMsg, setErrorMsg] = useState('')
  const [copied, setCopied] = useState(false)
  const [dragging, setDragging] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  async function handleTranscribe() {
    if (!file) return
    setStatus('uploading')
    setErrorMsg('')
    setTranscript('')

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    if (!supabaseUrl) {
      setErrorMsg('設定エラー: SUPABASE URL が未設定です。')
      setStatus('error')
      return
    }

    const endpoint = `${supabaseUrl}/functions/v1/mv3-transcribe?language=ja`

    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'x-mv3-pin': EXPECTED_PIN,
          'Content-Type': file.type || 'audio/mpeg',
        },
        body: file,
      })
      if (!res.ok) {
        const j = await res.json().catch(() => ({} as any))
        const msg =
          j?.error === 'unauthorized' ? 'パスコードが間違っています。' :
          j?.error === 'deepgram_failed' ? `音声の処理に失敗しました (${j.status})。` :
          j?.error || `エラー (${res.status})`
        throw new Error(msg)
      }
      const j = await res.json()
      const text = (j?.transcript || '').trim()
      if (!text) {
        setErrorMsg('文字起こし結果が空でした。音声を確認してください。')
        setStatus('error')
        return
      }
      setTranscript(text)
      setStatus('done')
    } catch (e: any) {
      setErrorMsg(e?.message || '失敗しました')
      setStatus('error')
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
    setStatus('idle')
    setErrorMsg('')
    if (fileRef.current) fileRef.current.value = ''
  }

  function pickFile(f: File | null) {
    if (!f) return
    setFile(f)
    setErrorMsg('')
  }

  return (
    <main className="min-h-screen bg-white">
      <div className="max-w-2xl mx-auto px-6 pt-16 pb-24">
        <header className="mb-10">
          <h1 className="text-3xl font-semibold text-neutral-900 tracking-tight">MP3 文字起こし</h1>
          <p className="mt-2 text-neutral-500 text-sm">
            MP3 ファイルを選んで「文字起こしをはじめる」を押してください。
          </p>
        </header>

        {status !== 'done' && (
          <section>
            <label
              htmlFor="mp3-file"
              onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
              onDragLeave={() => setDragging(false)}
              onDrop={(e) => {
                e.preventDefault()
                setDragging(false)
                pickFile(e.dataTransfer.files?.[0] ?? null)
              }}
              className={`block w-full rounded-3xl border border-dashed transition-colors cursor-pointer p-12 text-center ${
                dragging ? 'border-neutral-900 bg-neutral-100' : 'border-neutral-300 bg-neutral-50 hover:bg-neutral-100'
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
                {file ? `${(file.size / (1024 * 1024)).toFixed(1)} MB` : 'MP3 / M4A / WAV に対応'}
              </p>
              <input
                id="mp3-file"
                ref={fileRef}
                type="file"
                accept="audio/mpeg,audio/mp3,audio/mp4,audio/m4a,audio/wav,audio/x-wav,.mp3,.m4a,.wav"
                className="hidden"
                onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
              />
            </label>

            <button
              type="button"
              disabled={!file || status === 'uploading'}
              onClick={handleTranscribe}
              className="mt-6 w-full rounded-full bg-neutral-900 text-white text-base font-medium py-4 disabled:bg-neutral-300 transition-colors"
            >
              {status === 'uploading' ? '文字起こし中…' : '文字起こしをはじめる'}
            </button>

            {status === 'uploading' && (
              <p className="mt-4 text-center text-sm text-neutral-500">
                少し時間がかかります。このまま待っていてください。
              </p>
            )}

            {errorMsg && status === 'error' && (
              <p className="mt-4 text-center text-sm text-red-600">{errorMsg}</p>
            )}
          </section>
        )}

        {status === 'done' && (
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
