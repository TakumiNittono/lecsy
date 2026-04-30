'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bjqilokchrqfxzimfnpm.supabase.co';

type AppStatus =
  | 'idle'
  | 'requesting'
  | 'listening'
  | 'speaking'
  | 'reconnecting'
  | 'error';

type TranscriptItem = {
  id: string;
  english: string;
  japanese?: string;
  isFinal: boolean;
  ts: number;
};

const STATUS_LABEL: Record<AppStatus, string> = {
  idle: '停止中',
  requesting: 'マイク準備中…',
  listening: '聞き取り中',
  speaking: '英語を読み上げ中・マイク一時停止',
  reconnecting: '接続を復帰中…',
  error: 'エラー',
};

const MAX_ITEMS = 20;

export default function KPage() {
  const [status, setStatus] = useState<AppStatus>('idle');
  const [items, setItems] = useState<TranscriptItem[]>([]);
  const [interim, setInterim] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const [questionJa, setQuestionJa] = useState('');
  const [questionEn, setQuestionEn] = useState('');
  const [translatingQ, setTranslatingQ] = useState(false);
  const [showLarge, setShowLarge] = useState(false);

  const socketRef = useRef<WebSocket | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const mutedRef = useRef(false);
  const reconnectAttemptsRef = useRef(0);
  const stoppedManuallyRef = useRef(false);

  const pushFinal = useCallback((english: string) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    setItems((prev) => {
      const next = [...prev, { id, english, isFinal: true, ts: Date.now() }];
      return next.slice(-MAX_ITEMS);
    });
    void translateEnToJa(english).then((ja) => {
      if (!ja) return;
      setItems((prev) => prev.map((it) => (it.id === id ? { ...it, japanese: ja } : it)));
    });
  }, []);

  const startListening = useCallback(async () => {
    setErrorMsg(null);
    stoppedManuallyRef.current = false;
    setStatus('requesting');
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });
      streamRef.current = stream;

      const tokenRes = await fetch(
        `${SUPABASE_URL}/functions/v1/k-deepgram-token`,
        { method: 'POST' }
      );
      if (!tokenRes.ok) throw new Error('token_failed');
      const { token, url } = (await tokenRes.json()) as { token: string; url: string };

      await openSocket(stream, url, token);
    } catch (e) {
      console.error(e);
      setErrorMsg('マイクまたは接続を開始できませんでした。ブラウザのマイク許可を確認してください。');
      setStatus('error');
      cleanup();
    }
  }, []);

  const openSocket = useCallback(
    async (stream: MediaStream, url: string, token: string) => {
      const socket = new WebSocket(url, ['token', token]);
      socketRef.current = socket;

      socket.onopen = () => {
        reconnectAttemptsRef.current = 0;
        setStatus('listening');

        const mime = pickMime();
        const recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
        recorderRef.current = recorder;
        recorder.ondataavailable = (event) => {
          if (mutedRef.current) return;
          if (socket.readyState !== WebSocket.OPEN) return;
          if (event.data && event.data.size > 0) socket.send(event.data);
        };
        recorder.start(250);
      };

      socket.onmessage = (msg) => {
        try {
          const data = JSON.parse(msg.data);
          if (data.type && data.type !== 'Results') return;
          const alt = data.channel?.alternatives?.[0];
          const transcript: string = alt?.transcript ?? '';
          if (!transcript) return;
          if (data.is_final) {
            setInterim('');
            pushFinal(transcript);
          } else {
            setInterim(transcript);
          }
        } catch {
          /* ignore */
        }
      };

      socket.onerror = () => {
        if (stoppedManuallyRef.current) return;
        attemptReconnect();
      };
      socket.onclose = () => {
        if (stoppedManuallyRef.current) return;
        attemptReconnect();
      };
    },
    [pushFinal]
  );

  const attemptReconnect = useCallback(() => {
    if (stoppedManuallyRef.current) return;
    if (reconnectAttemptsRef.current >= 3) {
      setStatus('error');
      setErrorMsg('接続を復帰できませんでした。Restart Listening を押してください。');
      cleanup();
      return;
    }
    reconnectAttemptsRef.current += 1;
    setStatus('reconnecting');
    try {
      recorderRef.current?.stop();
    } catch {
      /* ignore */
    }
    setTimeout(() => {
      if (stoppedManuallyRef.current) return;
      void (async () => {
        try {
          const tokenRes = await fetch(
            `${SUPABASE_URL}/functions/v1/k-deepgram-token`,
            { method: 'POST' }
          );
          if (!tokenRes.ok) throw new Error('token_failed');
          const { token, url } = (await tokenRes.json()) as { token: string; url: string };
          if (!streamRef.current) throw new Error('no_stream');
          await openSocket(streamRef.current, url, token);
        } catch {
          attemptReconnect();
        }
      })();
    }, 800);
  }, [openSocket]);

  const stopListening = useCallback(() => {
    stoppedManuallyRef.current = true;
    cleanup();
    setStatus('idle');
  }, []);

  const cleanup = useCallback(() => {
    try {
      recorderRef.current?.stop();
    } catch {
      /* ignore */
    }
    recorderRef.current = null;
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    try {
      socketRef.current?.close();
    } catch {
      /* ignore */
    }
    socketRef.current = null;
  }, []);

  useEffect(() => {
    return () => {
      stoppedManuallyRef.current = true;
      cleanup();
    };
  }, [cleanup]);

  const onTranslateQuestion = useCallback(async (text?: string) => {
    const src = (text ?? questionJa).trim();
    if (!src) return;
    setQuestionJa(src);
    setTranslatingQ(true);
    setQuestionEn('');
    try {
      const en = await translateJaToEn(src);
      setQuestionEn(en ?? '');
    } catch {
      setErrorMsg('翻訳に失敗しました。もう一度お試しください。');
    } finally {
      setTranslatingQ(false);
    }
  }, [questionJa]);

  const onSpeakEnglish = useCallback(async () => {
    if (!questionEn.trim()) return;
    const wasListening = socketRef.current?.readyState === WebSocket.OPEN;
    mutedRef.current = true;
    if (wasListening) setStatus('speaking');

    try {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/k-tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: questionEn }),
      });
      if (!res.ok) throw new Error('tts_failed');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const audio = new Audio(url);
      await new Promise<void>((resolve) => {
        audio.onended = () => resolve();
        audio.onerror = () => resolve();
        void audio.play();
      });
      URL.revokeObjectURL(url);
    } catch {
      setErrorMsg('音声読み上げに失敗しました。英語文を画面で見せてください。');
    } finally {
      await new Promise((r) => setTimeout(r, 700));
      mutedRef.current = false;
      if (wasListening) setStatus('listening');
    }
  }, [questionEn]);

  return (
    <main className="mx-auto max-w-2xl px-4 py-6 pb-32">
      <header className="mb-4">
        <h1 className="text-xl font-bold">Hospital Live Interpreter</h1>
        <p className="text-xs text-slate-400 mt-1">
          英語→日本語リアルタイム通訳 / 日本語質問の英訳
        </p>
      </header>

      <StatusBar status={status} />
      {errorMsg && (
        <div className="mt-3 rounded-lg border border-red-500/40 bg-red-950/40 px-3 py-2 text-sm text-red-200">
          {errorMsg}
        </div>
      )}

      <div className="mt-4 flex gap-2">
        {status === 'idle' || status === 'error' ? (
          <button
            onClick={startListening}
            className="flex-1 rounded-xl bg-emerald-500 px-4 py-4 text-lg font-semibold text-emerald-950 active:bg-emerald-400"
          >
            Start Listening
          </button>
        ) : (
          <button
            onClick={stopListening}
            className="flex-1 rounded-xl bg-rose-500 px-4 py-4 text-lg font-semibold text-rose-950 active:bg-rose-400"
          >
            Stop
          </button>
        )}
      </div>

      <section className="mt-6">
        <h2 className="mb-2 text-xs uppercase tracking-wider text-slate-400">
          Doctor / Nurse said
        </h2>
        <TranscriptFeed items={items} interim={interim} />
      </section>

      <section className="mt-8">
        <h2 className="mb-2 text-xs uppercase tracking-wider text-slate-400">
          Ask in Japanese
        </h2>
        <textarea
          value={questionJa}
          onChange={(e) => setQuestionJa(e.target.value)}
          placeholder="日本語で質問を入力..."
          rows={3}
          className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-3 text-base text-slate-100 placeholder:text-slate-500 focus:border-emerald-500 focus:outline-none"
        />
        <div className="mt-2 flex flex-wrap gap-2">
          <button
            onClick={() => onTranslateQuestion()}
            disabled={!questionJa.trim() || translatingQ}
            className="flex-1 rounded-lg bg-sky-500 px-4 py-3 font-semibold text-sky-950 active:bg-sky-400 disabled:opacity-40"
          >
            {translatingQ ? 'Translating…' : 'Translate to English'}
          </button>
          <button
            onClick={() => {
              setQuestionJa('');
              setQuestionEn('');
            }}
            className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-3 text-slate-200 active:bg-slate-800"
          >
            Clear
          </button>
        </div>

        {questionEn && (
          <div className="mt-3 rounded-lg border border-slate-700 bg-slate-900 p-3">
            <div className="text-xs uppercase tracking-wider text-slate-400">English</div>
            <div className="mt-1 text-lg leading-snug text-slate-100">{questionEn}</div>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                onClick={() => setShowLarge(true)}
                className="flex-1 rounded-lg bg-amber-400 px-4 py-3 font-semibold text-amber-950 active:bg-amber-300"
              >
                Show English Large
              </button>
              <button
                onClick={onSpeakEnglish}
                className="flex-1 rounded-lg bg-emerald-500 px-4 py-3 font-semibold text-emerald-950 active:bg-emerald-400"
              >
                Speak English
              </button>
            </div>
          </div>
        )}
      </section>

      <SafetyNotice />

      {showLarge && questionEn && (
        <LargeEnglishModal
          english={questionEn}
          japanese={questionJa}
          onClose={() => setShowLarge(false)}
          onSpeak={onSpeakEnglish}
        />
      )}
    </main>
  );
}

function StatusBar({ status }: { status: AppStatus }) {
  const color =
    status === 'listening'
      ? 'bg-emerald-500'
      : status === 'speaking'
      ? 'bg-amber-400'
      : status === 'reconnecting' || status === 'requesting'
      ? 'bg-sky-500'
      : status === 'error'
      ? 'bg-rose-500'
      : 'bg-slate-500';
  return (
    <div className="flex items-center gap-2 rounded-lg border border-slate-800 bg-slate-900 px-3 py-2">
      <span className={`inline-block h-2.5 w-2.5 rounded-full ${color} ${status === 'listening' ? 'animate-pulse' : ''}`} />
      <span className="text-sm text-slate-200">{STATUS_LABEL[status]}</span>
    </div>
  );
}

function TranscriptFeed({
  items,
  interim,
}: {
  items: TranscriptItem[];
  interim: string;
}) {
  if (items.length === 0 && !interim) {
    return (
      <div className="rounded-lg border border-dashed border-slate-700 bg-slate-900/40 px-3 py-8 text-center text-sm text-slate-500">
        Start Listening を押すと、英語の会話が日本語でここに流れます。
      </div>
    );
  }
  return (
    <div className="space-y-3">
      {items.slice().reverse().map((it) => (
        <div
          key={it.id}
          className="rounded-lg border border-slate-800 bg-slate-900 p-3"
        >
          <div className="text-sm text-slate-300">{it.english}</div>
          {it.japanese ? (
            <div className="mt-2 text-lg font-medium leading-snug text-emerald-200">
              {it.japanese}
            </div>
          ) : (
            <div className="mt-2 text-sm text-slate-500">翻訳中…</div>
          )}
        </div>
      ))}
      {interim && (
        <div className="rounded-lg border border-dashed border-slate-700 bg-slate-900/40 p-3">
          <div className="text-sm text-slate-500">{interim}</div>
        </div>
      )}
    </div>
  );
}

function SafetyNotice() {
  return (
    <footer className="mt-10 rounded-lg border border-slate-800 bg-slate-900/50 p-4 text-xs leading-relaxed text-slate-400">
      <p className="font-semibold text-slate-300">Safety / 安全のお知らせ</p>
      <p className="mt-2">
        このツールは会話補助のためのものです。翻訳には誤りが含まれる可能性があります。これは正式な医療通訳ではありません。重要な医療判断は、必ず病院スタッフまたは正式な通訳に確認してください。
      </p>
      <p className="mt-2">音声・会話内容は保存されません (in-memory only)。</p>
      <p className="mt-2 text-slate-500">
        This tool is for communication support only. It may make mistakes. It is not a certified
        medical interpreter. For important medical decisions, please confirm with hospital staff or a
        certified interpreter. Audio is not stored.
      </p>
    </footer>
  );
}

function LargeEnglishModal({
  english,
  japanese,
  onClose,
  onSpeak,
}: {
  english: string;
  japanese: string;
  onClose: () => void;
  onSpeak: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-white text-slate-900">
      <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
        <span className="text-sm font-semibold">Show to staff</span>
        <button
          onClick={onClose}
          className="rounded-md bg-slate-900 px-3 py-1 text-sm font-semibold text-white"
        >
          Close
        </button>
      </div>
      <div className="flex flex-1 flex-col justify-center px-6">
        <p className="text-3xl font-bold leading-tight sm:text-4xl">{english}</p>
        <p className="mt-6 text-base text-slate-500">{japanese}</p>
      </div>
      <div className="border-t border-slate-200 p-4">
        <button
          onClick={onSpeak}
          className="w-full rounded-xl bg-emerald-500 px-4 py-4 text-lg font-semibold text-white active:bg-emerald-400"
        >
          Speak English
        </button>
      </div>
    </div>
  );
}

function pickMime(): string | null {
  if (typeof MediaRecorder === 'undefined') return null;
  const candidates = [
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/mp4;codecs=mp4a.40.2',
    'audio/mp4',
  ];
  for (const c of candidates) {
    try {
      if (MediaRecorder.isTypeSupported(c)) return c;
    } catch {
      /* ignore */
    }
  }
  return null;
}

async function translateEnToJa(text: string): Promise<string | null> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/k-translate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, direction: 'en-to-ja' }),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as { translation?: string };
    return data.translation ?? null;
  } catch {
    return null;
  }
}

async function translateJaToEn(text: string): Promise<string | null> {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/k-translate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, direction: 'ja-to-en' }),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as { translation?: string };
  return data.translation ?? null;
}
