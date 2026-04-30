'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { createClient } from '@/utils/supabase/client';

type SessionRow = {
  id: string;
  title: string | null;
  created_at: string;
  preview: string | null;
};

export default function KLibraryPage() {
  const supabase = useMemo(() => createClient(), []);
  const [rows, setRows] = useState<SessionRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      // ensure auth (匿名でも OK)
      const { data: u } = await supabase.auth.getUser();
      if (!u.user) {
        const { error: e } = await supabase.auth.signInAnonymously();
        if (e) {
          setError('履歴の読み込みにログインが必要ですが、匿名サインインに失敗しました。');
          setRows([]);
          return;
        }
      }
      const { data, error } = await supabase
        .from('k_sessions')
        .select('id, title, created_at, k_turns(japanese, english, created_at)')
        .order('created_at', { ascending: false })
        .limit(100);
      if (cancelled) return;
      if (error) {
        setError(error.message);
        setRows([]);
        return;
      }
      // preview = 最初の turn の japanese (なければ english)
      const mapped: SessionRow[] = (data ?? []).map((s: any) => {
        const turns: any[] = s.k_turns ?? [];
        turns.sort((a, b) => (a.created_at < b.created_at ? -1 : 1));
        const first = turns[0];
        const preview = first ? (first.japanese?.trim() || first.english?.trim() || null) : null;
        return {
          id: s.id,
          title: s.title,
          created_at: s.created_at,
          preview: preview ? preview.slice(0, 80) : null,
        };
      });
      setRows(mapped);
    })();
    return () => {
      cancelled = true;
    };
  }, [supabase]);

  return (
    <main className="mx-auto max-w-2xl px-4 py-6 pb-20">
      <header className="mb-4 flex items-center justify-between">
        <h1 className="text-xl font-bold">履歴</h1>
        <Link
          href="/k"
          className="rounded-md border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs text-slate-200 active:bg-slate-800"
        >
          ← 通訳に戻る
        </Link>
      </header>

      {error && (
        <div className="rounded-lg border border-red-500/40 bg-red-950/40 px-3 py-2 text-sm text-red-200">
          {error}
        </div>
      )}

      {rows === null ? (
        <div className="rounded-lg border border-slate-800 bg-slate-900/50 px-3 py-8 text-center text-sm text-slate-500">
          読み込み中…
        </div>
      ) : rows.length === 0 ? (
        <div className="rounded-lg border border-dashed border-slate-700 bg-slate-900/40 px-3 py-10 text-center text-sm text-slate-500">
          まだ履歴はありません。
          <br />
          /k で Start Listening を押すと、ここに残ります。
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((r) => (
            <li key={r.id}>
              <Link
                href={`/k/s/${r.id}`}
                className="block rounded-lg border border-slate-800 bg-slate-900 px-3 py-3 active:bg-slate-800"
              >
                <div className="flex items-center justify-between gap-3">
                  <span className="text-sm font-medium text-slate-200">
                    {r.title ?? new Date(r.created_at).toLocaleString('ja-JP')}
                  </span>
                  <span className="text-xs text-slate-500">
                    {new Date(r.created_at).toLocaleDateString('ja-JP')}
                  </span>
                </div>
                {r.preview && (
                  <div className="mt-1.5 line-clamp-2 text-sm text-slate-400">{r.preview}</div>
                )}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
