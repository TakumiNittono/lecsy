'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { createClient } from '@/utils/supabase/client';

type Turn = {
  id: string;
  kind: 'said' | 'question';
  english: string | null;
  japanese: string | null;
  created_at: string;
};

type Session = {
  id: string;
  title: string | null;
  created_at: string;
};

export default function KSessionPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [turns, setTurns] = useState<Turn[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (!params?.id) return;
    let cancelled = false;
    (async () => {
      const { data: u } = await supabase.auth.getUser();
      if (!u.user) {
        const { error: e } = await supabase.auth.signInAnonymously();
        if (e) {
          setError('読み込みに匿名サインインが必要ですが、失敗しました。');
          setTurns([]);
          return;
        }
      }
      const { data: s, error: se } = await supabase
        .from('k_sessions')
        .select('id, title, created_at')
        .eq('id', params.id)
        .maybeSingle();
      if (cancelled) return;
      if (se || !s) {
        setError(se?.message ?? '見つかりませんでした。');
        setTurns([]);
        return;
      }
      setSession(s);
      const { data: t, error: te } = await supabase
        .from('k_turns')
        .select('id, kind, english, japanese, created_at')
        .eq('session_id', params.id)
        .order('created_at', { ascending: true });
      if (cancelled) return;
      if (te) {
        setError(te.message);
        setTurns([]);
        return;
      }
      setTurns(t ?? []);
    })();
    return () => {
      cancelled = true;
    };
  }, [params?.id, supabase]);

  const onDelete = async () => {
    if (!params?.id) return;
    if (!confirm('このセッションを削除しますか？')) return;
    setDeleting(true);
    const { error } = await supabase.from('k_sessions').delete().eq('id', params.id);
    setDeleting(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.replace('/k/library');
  };

  return (
    <main className="mx-auto max-w-2xl px-4 py-6 pb-20">
      <header className="mb-4 flex items-center justify-between gap-3">
        <Link
          href="/k/library"
          className="rounded-md border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs text-slate-200 active:bg-slate-800"
        >
          ← 履歴
        </Link>
        <button
          onClick={onDelete}
          disabled={deleting}
          className="rounded-md border border-rose-500/40 bg-rose-950/40 px-3 py-1.5 text-xs text-rose-200 active:bg-rose-900 disabled:opacity-40"
        >
          {deleting ? '削除中…' : '削除'}
        </button>
      </header>

      {session && (
        <div className="mb-4">
          <h1 className="text-xl font-bold">
            {session.title ?? new Date(session.created_at).toLocaleString('ja-JP')}
          </h1>
          <p className="mt-1 text-xs text-slate-500">
            {new Date(session.created_at).toLocaleString('ja-JP')}
          </p>
        </div>
      )}

      {error && (
        <div className="mb-3 rounded-lg border border-red-500/40 bg-red-950/40 px-3 py-2 text-sm text-red-200">
          {error}
        </div>
      )}

      {turns === null ? (
        <div className="rounded-lg border border-slate-800 bg-slate-900/50 px-3 py-8 text-center text-sm text-slate-500">
          読み込み中…
        </div>
      ) : turns.length === 0 ? (
        <div className="rounded-lg border border-dashed border-slate-700 bg-slate-900/40 px-3 py-10 text-center text-sm text-slate-500">
          このセッションには発話がありません。
        </div>
      ) : (
        <ul className="space-y-3">
          {turns.map((t) => (
            <li
              key={t.id}
              className={`rounded-lg border p-3 ${
                t.kind === 'said'
                  ? 'border-slate-800 bg-slate-900'
                  : 'border-sky-500/30 bg-sky-950/30'
              }`}
            >
              <div className="text-[10px] uppercase tracking-wider text-slate-500">
                {t.kind === 'said' ? 'Speaker' : '家族の質問'}
              </div>
              {t.japanese && (
                <div className="mt-1 text-lg font-medium leading-snug text-emerald-200">
                  {t.japanese}
                </div>
              )}
              {t.english && (
                <div className="mt-1.5 text-sm text-slate-300">{t.english}</div>
              )}
              <div className="mt-2 text-[10px] text-slate-500">
                {new Date(t.created_at).toLocaleTimeString('ja-JP')}
              </div>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
