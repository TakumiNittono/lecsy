'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createClient } from '@/utils/supabase/client';

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bjqilokchrqfxzimfnpm.supabase.co';

type AppStatus =
  | 'idle'
  | 'requesting'
  | 'listening'
  | 'paused'
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

const MAX_ITEMS = 20;

export default function KPage() {
  const [status, setStatus] = useState<AppStatus>('idle');
  const [items, setItems] = useState<TranscriptItem[]>([]);
  const [interim, setInterim] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const [questionJa, setQuestionJa] = useState('');
  const [questionEn, setQuestionEn] = useState('');
  const [translatingQ, setTranslatingQ] = useState(false);

  const socketRef = useRef<WebSocket | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const mutedRef = useRef(false);
  const reconnectAttemptsRef = useRef(0);
  const stoppedManuallyRef = useRef(false);
  // 翻訳直列化用キュー: 前の翻訳が完了するまで次は始まらない。
  // 結果として日本語は必ず上の item から順に埋まる。
  const translateQueueRef = useRef<Promise<unknown>>(Promise.resolve());

  // Supabase: 匿名ログイン + 現セッション。
  const supabase = useMemo(() => createClient(), []);
  const sessionIdRef = useRef<string | null>(null);
  const userIdRef = useRef<string | null>(null);

  // 起動時に匿名 auth。既にログイン済ならそれを使う。
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase.auth.getUser();
      if (data.user) {
        userIdRef.current = data.user.id;
        return;
      }
      const { data: signed, error } = await supabase.auth.signInAnonymously();
      if (cancelled) return;
      if (error) {
        // 匿名 auth が project で disabled の場合など。保存は諦めるが live 通訳は続行。
        console.warn('[k] anon sign-in failed, history will not be saved', error);
        return;
      }
      userIdRef.current = signed.user?.id ?? null;
    })();
    return () => {
      cancelled = true;
    };
  }, [supabase]);

  // 現セッションを担保。なければ作成。auth が無ければ null を返す。
  const ensureSession = useCallback(async (): Promise<string | null> => {
    if (sessionIdRef.current) return sessionIdRef.current;
    if (!userIdRef.current) return null;
    const title = new Date().toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
    const { data, error } = await supabase
      .from('k_sessions')
      .insert({ user_id: userIdRef.current, title })
      .select('id')
      .single();
    if (error || !data) {
      console.warn('[k] session insert failed', error);
      return null;
    }
    sessionIdRef.current = data.id;
    return data.id;
  }, [supabase]);

  const saveTurn = useCallback(
    async (kind: 'said' | 'question', english: string, japanese: string) => {
      const sid = await ensureSession();
      if (!sid) return;
      const { error } = await supabase.from('k_turns').insert({
        session_id: sid,
        kind,
        english,
        japanese,
      });
      if (error) console.warn('[k] turn insert failed', error);
    },
    [supabase, ensureSession]
  );

  const pushFinal = useCallback((english: string) => {
    const trimmed = english.trim();
    if (!trimmed) return;
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    // チャット風: 新しいものが末尾。古いものは押し上がる。
    setItems((prev) => {
      const next = [...prev, { id, english: trimmed, isFinal: true, ts: Date.now() }];
      return next.slice(-MAX_ITEMS);
    });
    const shouldTranslate = trimmed.length > 2 && /\s|[.!?]/.test(trimmed) || trimmed.length > 6;
    if (!shouldTranslate) {
      // 翻訳しないが履歴には残す (英語のみ)
      void saveTurn('said', trimmed, '');
      return;
    }
    // チェーン: 前の翻訳が終わってから次を開始。例外でチェーンが切れないように catch。
    translateQueueRef.current = translateQueueRef.current.then(async () => {
      try {
        const ja = await translateStream(trimmed, 'en-to-ja', (delta) => {
          setItems((prev) =>
            prev.map((it) =>
              it.id === id ? { ...it, japanese: (it.japanese ?? '') + delta } : it
            )
          );
        });
        void saveTurn('said', trimmed, ja);
      } catch (e) {
        console.warn('[k] translate failed', e);
      }
    });
  }, [saveTurn]);

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

  const pauseListening = useCallback(() => {
    // mic を mute するだけ。WS と stream は維持。セッションも維持。
    mutedRef.current = true;
    setStatus('paused');
  }, []);

  const resumeListening = useCallback(() => {
    mutedRef.current = false;
    setStatus('listening');
  }, []);

  const stopListening = useCallback(() => {
    stoppedManuallyRef.current = true;
    cleanup();
    setStatus('idle');
    // 次回 Start Listening で新セッションを開始する。
    sessionIdRef.current = null;
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
      const en = await translateStream(src, 'ja-to-en', (delta) => {
        setQuestionEn((prev) => prev + delta);
      });
      // 質問は kind='question'。english=訳, japanese=元の質問。
      void saveTurn('question', en, src);
    } catch {
      setErrorMsg('翻訳に失敗しました。もう一度お試しください。');
    } finally {
      setTranslatingQ(false);
    }
  }, [questionJa, saveTurn]);

  // text を英語として TTS 再生。listening 中は mic を mute して loopback を防ぐ。
  const speakText = useCallback(async (text: string) => {
    const t = text.trim();
    if (!t) return;
    const wasListening = socketRef.current?.readyState === WebSocket.OPEN;
    mutedRef.current = true;
    if (wasListening) setStatus('speaking');

    try {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/k-tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: t }),
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
  }, []);

  const onClearQuestion = useCallback(() => {
    setQuestionJa('');
    setQuestionEn('');
  }, []);

  const isLive = status === 'listening' || status === 'paused' || status === 'speaking' || status === 'reconnecting' || status === 'requesting';

  return (
    <main className="mx-auto flex min-h-[100dvh] max-w-2xl flex-col px-4">
      {/* sticky top: タイトル + ステータスドット + 操作ボタンを上に固定。 */}
      <div className="sticky top-0 z-20 -mx-4 border-b border-slate-800 bg-slate-950/95 px-4 pb-3 pt-[max(env(safe-area-inset-top),0.75rem)] backdrop-blur">
        <header className="mb-3 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2 min-w-0">
            <span className={`inline-block h-2 w-2 shrink-0 rounded-full ${dotColor(status)} ${status === 'listening' ? 'animate-pulse' : ''}`} />
            <h1 className="truncate text-base font-semibold">Hospital Live Interpreter</h1>
          </div>
          <Link
            href="/k/library"
            className="shrink-0 rounded-md border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs text-slate-200 active:bg-slate-800"
          >
            履歴
          </Link>
        </header>

        <div className="flex gap-2">
          {status === 'requesting' || status === 'reconnecting' ? (
            <button
              disabled
              className="flex-1 inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-500/30 px-4 py-3.5 text-base font-semibold text-emerald-200"
            >
              <Spinner className="h-5 w-5" />
              {status === 'requesting' ? '起動中…' : '再接続中…'}
            </button>
          ) : !isLive ? (
            <button
              onClick={startListening}
              className="flex-1 rounded-xl bg-emerald-500 px-4 py-3.5 text-base font-semibold text-emerald-950 active:bg-emerald-400"
            >
              Start
            </button>
          ) : (
            <>
              {status === 'paused' ? (
                <button
                  onClick={resumeListening}
                  className="flex-1 rounded-xl bg-emerald-500 px-4 py-3.5 text-base font-semibold text-emerald-950 active:bg-emerald-400"
                >
                  Resume
                </button>
              ) : (
                <button
                  onClick={pauseListening}
                  disabled={status !== 'listening'}
                  className="flex-1 rounded-xl bg-slate-700 px-4 py-3.5 text-base font-semibold text-slate-100 active:bg-slate-600 disabled:opacity-40"
                >
                  Pause
                </button>
              )}
              <button
                onClick={stopListening}
                className="flex-1 rounded-xl bg-rose-500 px-4 py-3.5 text-base font-semibold text-rose-950 active:bg-rose-400"
              >
                Stop
              </button>
            </>
          )}
        </div>

        {errorMsg && (
          <div className="mt-2 rounded-lg bg-red-950/50 px-3 py-2 text-sm text-red-200">
            {errorMsg}
          </div>
        )}
      </div>

      <section className="mt-4 flex-1">
        <TranscriptFeed items={items} />
      </section>

      {/* sticky bottom: interim (リアルタイム聞き取り) + 入力 + 翻訳結果。 */}
      <section className="sticky bottom-0 -mx-4 border-t border-slate-800 bg-slate-950/95 px-4 pb-[max(env(safe-area-inset-bottom),0.75rem)] pt-3 backdrop-blur">
        {interim && (
          <div className="mb-2 flex items-start gap-2 rounded-lg border border-emerald-500/50 bg-emerald-950/40 px-3 py-2.5">
            <span className="mt-1.5 inline-block h-2 w-2 shrink-0 animate-pulse rounded-full bg-emerald-400" />
            <div className="flex-1 text-base leading-snug text-emerald-100">{interim}</div>
          </div>
        )}
        <div className="relative">
          <textarea
            value={questionJa}
            onChange={(e) => setQuestionJa(e.target.value)}
            placeholder="日本語で質問を入力..."
            rows={2}
            className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 pr-9 text-base text-slate-100 placeholder:text-slate-500 focus:border-emerald-500 focus:outline-none"
          />
          {(questionJa || questionEn) && (
            <button
              onClick={onClearQuestion}
              aria-label="入力をクリア"
              className="absolute right-1.5 top-1.5 rounded-md p-1.5 text-slate-400 active:bg-slate-700 active:text-slate-100"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
                className="h-4 w-4"
                aria-hidden
              >
                <path d="M18 6L6 18M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>
        <button
          onClick={() => onTranslateQuestion()}
          disabled={!questionJa.trim() || translatingQ}
          className="mt-2 w-full rounded-lg bg-sky-500 px-4 py-3 font-semibold text-sky-950 active:bg-sky-400 disabled:opacity-40"
        >
          {translatingQ ? 'Translating…' : 'Translate to English'}
        </button>

        {questionEn && (
          <div className="mt-3 flex items-start gap-2 rounded-lg border border-amber-300/30 bg-amber-50 px-4 py-3 shadow-sm">
            <div className="flex-1 text-xl font-medium leading-relaxed tracking-tight text-slate-900">
              {questionEn}
            </div>
            <button
              onClick={() => void speakText(questionEn)}
              aria-label="英語を読み上げる"
              className="shrink-0 rounded-md p-1.5 text-slate-600 active:bg-amber-100 active:text-slate-900"
            >
              <SpeakerIcon className="h-5 w-5" />
            </button>
          </div>
        )}

        <p className="mt-3 text-[11px] leading-relaxed text-slate-500">
          会話補助のためのツール。重要な医療判断は必ずスタッフに確認を。音声は保存されません。
        </p>
      </section>

    </main>
  );
}

function Spinner({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={`animate-spin ${className ?? ''}`} aria-hidden>
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeOpacity="0.25" strokeWidth="3" />
      <path d="M22 12a10 10 0 00-10-10" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
    </svg>
  );
}

function SpeakerIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
    >
      <path d="M11 5L6 9H2v6h4l5 4V5z" />
      <path d="M15.5 8.5a5 5 0 010 7" />
      <path d="M19 5a10 10 0 010 14" />
    </svg>
  );
}

function dotColor(status: AppStatus): string {
  switch (status) {
    case 'listening': return 'bg-emerald-500';
    case 'speaking': return 'bg-amber-400';
    case 'paused': return 'bg-slate-400';
    case 'reconnecting':
    case 'requesting': return 'bg-sky-500';
    case 'error': return 'bg-rose-500';
    default: return 'bg-slate-600';
  }
}

function TranscriptFeed({
  items,
}: {
  items: TranscriptItem[];
}) {
  const itemRefs = useRef<Map<string, HTMLDivElement | null>>(new Map());
  const lastScrolledRef = useRef<string | null>(null);

  // 新しい item が確定するたび、その item を viewport の中央に持ってくる。
  // sticky top + sticky bottom で挟まれていてもセンター揃えは正しく機能する。
  // 同じ item に対しては 1 回だけ。interim 更新中は走らない。
  useEffect(() => {
    const last = items[items.length - 1];
    if (!last) return;
    if (lastScrolledRef.current === last.id) return;
    lastScrolledRef.current = last.id;
    const el = itemRefs.current.get(last.id);
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, [items]);

  if (items.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-slate-700 bg-slate-900/40 px-3 py-8 text-center text-sm text-slate-500">
        Start を押すと、英語の会話が日本語でここに流れます。
      </div>
    );
  }
  return (
    <div className="space-y-3">
      {/* 確定 item は古→新で上から下へ。新しいものが入った瞬間に画面センターへスクロール。
          英語と日本語のペアは順序を厳守 (各 item の id で固定)。後から来た翻訳が
          先のものを追い越して並ぶことはない。interim は sticky bottom 側で表示。 */}
      {items.map((it) => (
        <div
          key={it.id}
          ref={(node) => {
            if (node) itemRefs.current.set(it.id, node);
            else itemRefs.current.delete(it.id);
          }}
          className="rounded-lg border border-slate-800 bg-slate-900 p-3"
        >
          {it.japanese ? (
            <div className="text-lg font-medium leading-snug text-emerald-200">
              {it.japanese}
            </div>
          ) : (
            <div className="text-sm text-slate-500">翻訳中…</div>
          )}
          <div className="mt-1.5 text-xs text-slate-400">{it.english}</div>
        </div>
      ))}
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

// SSE をストリームで読み、delta が来るたびに onDelta を呼ぶ。最終的な全文を返す。
// 形式は OpenAI Chat Completions の SSE そのまま (k-translate がそのまま転送している)。
async function translateStream(
  text: string,
  direction: 'en-to-ja' | 'ja-to-en',
  onDelta: (delta: string) => void
): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/k-translate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, direction }),
  });
  if (!res.ok || !res.body) return '';

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buf = '';
  let full = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    let idx: number;
    while ((idx = buf.indexOf('\n')) !== -1) {
      const line = buf.slice(0, idx).trim();
      buf = buf.slice(idx + 1);
      if (!line.startsWith('data:')) continue;
      const payload = line.slice(5).trim();
      if (payload === '[DONE]') return full;
      try {
        const obj = JSON.parse(payload);
        const delta: string = obj.choices?.[0]?.delta?.content ?? '';
        if (delta) {
          full += delta;
          onDelta(delta);
        }
      } catch {
        /* skip malformed line */
      }
    }
  }
  return full;
}
