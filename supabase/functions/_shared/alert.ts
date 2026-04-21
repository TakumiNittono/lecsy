// supabase/functions/_shared/alert.ts
//
// 統一アラートヘルパ。Edge Function の失敗/警告を1箇所から:
//   1. Slack (#alerts channel) — 人間が即気づく
//   2. Sentry                  — スタックトレース + 集計
//   3. system_alerts テーブル  — DB 監査記録
// の3経路に同時送出する。
//
// 環境変数 (全て optional):
//   SLACK_WEBHOOK_URL  — https://hooks.slack.com/services/...
//   SENTRY_DSN         — https://<key>@<host>/<project_id>
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — system_alerts 書込用
//
// 設計原則:
//   - 全 optional: env 未設定でも本体処理を絶対に止めない
//   - 例外捕捉: alert 自身の失敗で呼出元を落とさない (全部 console.error に押込む)
//   - 重複抑制なし: 5/1パイロット期間は「多すぎる」より「漏れる」方が致命的

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type AlertLevel = 'info' | 'warning' | 'error' | 'critical';

export interface AlertInput {
  /** どの Edge Function / 機能から出ているか (e.g. 'deepgram-token') */
  source: string;
  /** レベル。critical は自動機能停止と連動させること */
  level: AlertLevel;
  /** 人間向け1行メッセージ */
  message: string;
  /** 関連情報 (user_id, org_id, balance, status code, …) */
  context?: Record<string, unknown>;
  /** Error オブジェクトがあれば Sentry にスタック送る */
  error?: unknown;
}

const SLACK_EMOJI: Record<AlertLevel, string> = {
  info: ':information_source:',
  warning: ':warning:',
  error: ':x:',
  critical: ':rotating_light:',
};

/**
 * アラート送信。どこかで失敗しても例外は投げない。
 * 呼出側は `await alert({...}).catch(() => {})` で包む必要なし。
 */
export async function alert(input: AlertInput): Promise<void> {
  const ts = new Date().toISOString();
  // 並行送出。いずれかが遅くてもブロックしない。
  await Promise.allSettled([
    postSlack(input, ts),
    postSentry(input),
    writeSystemAlert(input, ts),
  ]);
}

async function postSlack(input: AlertInput, ts: string): Promise<void> {
  const url = Deno.env.get('SLACK_WEBHOOK_URL');
  if (!url) return;
  const emoji = SLACK_EMOJI[input.level];
  const contextLines = input.context
    ? Object.entries(input.context)
        .map(([k, v]) => `• *${k}*: \`${safeJson(v)}\``)
        .join('\n')
    : '';
  const text =
    `${emoji} *${input.source}* — ${input.level.toUpperCase()}\n` +
    `${input.message}\n` +
    (contextLines ? `${contextLines}\n` : '') +
    `_${ts}_`;
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
    });
  } catch (e) {
    console.error('[alert] slack post failed', e);
  }
}

async function postSentry(input: AlertInput): Promise<void> {
  const dsn = Deno.env.get('SENTRY_DSN');
  if (!dsn) return;
  try {
    const parsed = parseDsn(dsn);
    if (!parsed) return;
    const { host, projectId, publicKey } = parsed;

    const ex = input.error;
    const errorInfo =
      ex instanceof Error
        ? {
            type: ex.name || 'Error',
            value: ex.message,
            stacktrace: { frames: parseStack(ex.stack) },
          }
        : null;

    const event = {
      event_id: crypto.randomUUID().replace(/-/g, ''),
      timestamp: new Date().toISOString(),
      platform: 'javascript',
      level: sentryLevel(input.level),
      logger: input.source,
      environment: Deno.env.get('SENTRY_ENVIRONMENT') ?? 'production',
      release: Deno.env.get('SENTRY_RELEASE') ?? undefined,
      server_name: input.source,
      tags: { source: input.source },
      extra: input.context ?? {},
      message: { formatted: input.message },
      exception: errorInfo ? { values: [errorInfo] } : undefined,
    };

    const auth =
      `Sentry sentry_version=7,` +
      `sentry_client=lecsy-edge/1.0,` +
      `sentry_key=${publicKey}`;

    await fetch(`https://${host}/api/${projectId}/store/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Sentry-Auth': auth,
      },
      body: JSON.stringify(event),
    });
  } catch (e) {
    console.error('[alert] sentry post failed', e);
  }
}

async function writeSystemAlert(input: AlertInput, ts: string): Promise<void> {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return;
  try {
    // deno-lint-ignore no-explicit-any
    const sb = createClient<any, any, any>(url, key);
    await sb.from('system_alerts').insert({
      source: input.source,
      level: input.level === 'critical' ? 'critical' : input.level === 'error' ? 'critical' : 'warning',
      message: input.message,
      payload: {
        ...(input.context ?? {}),
        original_level: input.level,
        ts,
      },
    });
  } catch (e) {
    console.error('[alert] system_alerts insert failed', e);
  }
}

function sentryLevel(l: AlertLevel): string {
  switch (l) {
    case 'info':
      return 'info';
    case 'warning':
      return 'warning';
    case 'error':
      return 'error';
    case 'critical':
      return 'fatal';
  }
}

function parseDsn(dsn: string): { host: string; projectId: string; publicKey: string } | null {
  try {
    const u = new URL(dsn);
    const projectId = u.pathname.replace(/^\//, '');
    return { host: u.host, projectId, publicKey: u.username };
  } catch {
    return null;
  }
}

function parseStack(stack?: string) {
  if (!stack) return [];
  const frames: { filename: string; function: string; lineno?: number; colno?: number }[] = [];
  for (const raw of stack.split('\n').slice(1)) {
    const m = raw.match(/at (.+?) \((.+?):(\d+):(\d+)\)/);
    if (m) {
      frames.unshift({
        function: m[1],
        filename: m[2],
        lineno: Number(m[3]),
        colno: Number(m[4]),
      });
      continue;
    }
    const m2 = raw.match(/at (.+?):(\d+):(\d+)/);
    if (m2) {
      frames.unshift({
        function: '<anonymous>',
        filename: m2[1],
        lineno: Number(m2[2]),
        colno: Number(m2[3]),
      });
    }
  }
  return frames;
}

function safeJson(v: unknown): string {
  try {
    if (typeof v === 'string') return v;
    return JSON.stringify(v);
  } catch {
    return String(v);
  }
}

/**
 * try/catch で包んだ関数実行。失敗したら alert を出して再 throw。
 * Edge Function の main ハンドラを `withAlert(source, async () => {...})`
 * で包むのが楽。
 */
export function withAlert<T>(
  source: string,
  fn: () => Promise<T>
): () => Promise<T> {
  return async () => {
    try {
      return await fn();
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      await alert({
        source,
        level: 'error',
        message: `Unhandled error: ${message}`,
        error: e,
      });
      throw e;
    }
  };
}

/**
 * `Deno.serve` / `serve` ハンドラを包むラッパ。未捕捉例外を alert → 500 で返す。
 *
 *   serve(handleWithAlert('translate-realtime', async (req) => { ... }));
 *
 * これだけで「関数内のどこで throw しても Slack に飛ぶ」状態になる。
 */
export function handleWithAlert(
  source: string,
  handler: (req: Request) => Promise<Response> | Response,
): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    try {
      return await handler(req);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      await alert({
        source,
        level: 'error',
        message: `Unhandled error: ${message}`,
        context: {
          url: req.url,
          method: req.method,
        },
        error: e,
      });
      return new Response(
        JSON.stringify({ error: 'internal_error', detail: message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      );
    }
  };
}
