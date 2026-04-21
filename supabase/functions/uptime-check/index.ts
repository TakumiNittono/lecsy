// supabase/functions/uptime-check/index.ts
//
// 自前 uptime monitor。Better Stack の代替。
//
// 動作:
//   - 複数 URL を並行 HEAD fetch (タイムアウト付き)
//   - 失敗したら _shared/alert.ts 経由で Slack + Sentry に通知
//   - 成功したらサイレント (ログのみ)
//   - dedup はしない (5分間隔で runs × 失敗=最大 12alerts/hr、許容)
//
// 監視対象:
//   - https://www.lecsy.app                          (Vercel 本番)
//   - https://bjqilokchrqfxzimfnpm.supabase.co/rest/v1/ (Supabase 自身の外形 — 意味は薄いが Cloudflare 経由での reachability 確認用)
//
// cron 登録 (Supabase Dashboard > Database > Cron):
//   select cron.schedule(
//     'uptime-check',
//     '*/5 * * * *',  -- 5分毎
//     $$ select net.http_post(
//       url := 'https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/uptime-check',
//       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
//     ) $$
//   );

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { alert } from '../_shared/alert.ts';

interface Target {
  name: string;
  url: string;
  /** HTTP 成功とみなすステータスコード範囲 */
  acceptStatus: (s: number) => boolean;
  /** ms。超えたら失敗扱い */
  timeoutMs: number;
  /** request に追加する header (例: Supabase REST の apikey) */
  headers?: Record<string, string>;
}

// apikey は Function の env (SUPABASE_ANON_KEY) から取る。ハードコードしない。
// Supabase Edge Function では SUPABASE_ANON_KEY は Platform 側で自動注入される。
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://bjqilokchrqfxzimfnpm.supabase.co';

const TARGETS: Target[] = [
  {
    name: 'www.lecsy.app',
    url: 'https://www.lecsy.app',
    acceptStatus: (s) => s >= 200 && s < 400,
    timeoutMs: 10_000,
  },
  {
    name: 'supabase-rest',
    url: `${SUPABASE_URL}/rest/v1/`,
    acceptStatus: (s) => s === 200 || s === 401 || s === 404, // 200 or auth 系 = 到達OK
    timeoutMs: 10_000,
    headers: SUPABASE_ANON_KEY ? { apikey: SUPABASE_ANON_KEY } : undefined,
  },
];

interface Result {
  name: string;
  url: string;
  ok: boolean;
  status?: number;
  latency_ms: number;
  error?: string;
}

serve(async () => {
  const results = await Promise.all(TARGETS.map(check));

  const failures = results.filter((r) => !r.ok);
  for (const f of failures) {
    await alert({
      source: 'uptime-check',
      level: 'critical',
      message: `${f.name} is DOWN — ${f.error ?? `status ${f.status}`}`,
      context: {
        url: f.url,
        status: f.status,
        latency_ms: f.latency_ms,
        error: f.error,
      },
    });
  }

  return new Response(
    JSON.stringify({
      checked_at: new Date().toISOString(),
      results,
      failures: failures.length,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
});

async function check(t: Target): Promise<Result> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), t.timeoutMs);
  const start = Date.now();
  try {
    const res = await fetch(t.url, {
      method: 'GET',
      headers: t.headers,
      signal: controller.signal,
      redirect: 'follow',
    });
    const latency = Date.now() - start;
    const ok = t.acceptStatus(res.status);
    return {
      name: t.name,
      url: t.url,
      ok,
      status: res.status,
      latency_ms: latency,
      error: ok ? undefined : `unexpected status ${res.status}`,
    };
  } catch (e) {
    const latency = Date.now() - start;
    const msg = e instanceof Error ? e.message : String(e);
    return {
      name: t.name,
      url: t.url,
      ok: false,
      latency_ms: latency,
      error: controller.signal.aborted ? `timeout after ${t.timeoutMs}ms` : msg,
    };
  } finally {
    clearTimeout(timer);
  }
}
