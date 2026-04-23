// MP3 文字起こし用 Edge Function (母用 /mp3 ページ専用)
//
// 役割:
//   - PIN (MV3_PIN, default "0816") を timing-safe 比較で検証
//   - ブラウザから届いた音声ストリームを **バッファせず** Deepgram に直送する
//     (req.body → Deepgram POST body の pass-through)
//   - 生成結果 (transcript) のみ JSON で返す
//
// なぜストリーミング:
//   arrayBuffer() で全体を一度メモリに載せると、85MB 超で worker_limit (546) に落ちる。
//   stream 経由なら、Supabase Edge Function の 256MB メモリ上限に触れず数百 MB 級まで通る。
//
// 保存は一切しない。Deepgram 処理が終わった時点で音声は揮発する。
//
// 必要 secrets: DEEPGRAM_ADMIN_KEY, MV3_PIN

import { timingSafeEqual } from 'https://deno.land/std@0.224.0/crypto/timing_safe_equal.ts';

const DEEPGRAM_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY');
const EXPECTED_PIN = Deno.env.get('MV3_PIN') ?? '0816';

const DEFAULT_ORIGINS = [
  'https://www.lecsy.app',
  'https://lecsy.app',
  'http://localhost:3000',
  'http://localhost:3020',
];
const ENV_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',').map((s) => s.trim()).filter(Boolean);
const ALLOWED = Array.from(new Set([...DEFAULT_ORIGINS, ...ENV_ORIGINS]));

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('origin') ?? '';
  const allowOrigin = ALLOWED.includes(origin) ? origin : ALLOWED[0];
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'content-type, x-mv3-pin, authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function pinOk(pin: string | null): boolean {
  if (!pin) return false;
  const enc = new TextEncoder();
  const a = enc.encode(pin);
  const b = enc.encode(EXPECTED_PIN);
  if (a.byteLength !== b.byteLength) return false;
  return timingSafeEqual(a, b);
}

function jsonRes(req: Request, body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(req) },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== 'POST') {
    return jsonRes(req, { error: 'method_not_allowed' }, 405);
  }
  if (!DEEPGRAM_KEY) {
    return jsonRes(req, { error: 'server_misconfigured' }, 500);
  }
  if (!pinOk(req.headers.get('x-mv3-pin'))) {
    return jsonRes(req, { error: 'unauthorized' }, 401);
  }
  if (!req.body) {
    return jsonRes(req, { error: 'no_body' }, 400);
  }

  const url = new URL(req.url);
  const langParam = url.searchParams.get('language') ?? 'ja';
  const language = ['ja', 'en', 'en-US'].includes(langParam) ? langParam : 'ja';

  const params = new URLSearchParams({
    model: 'nova-2-general',
    language,
    smart_format: 'true',
    punctuate: 'true',
    paragraphs: 'true',
  });

  // req.body を Deepgram にストリーミング pass-through (バッファしない)
  const dgRes = await fetch(`https://api.deepgram.com/v1/listen?${params.toString()}`, {
    method: 'POST',
    headers: {
      Authorization: `Token ${DEEPGRAM_KEY}`,
      'Content-Type': req.headers.get('content-type') ?? 'audio/mpeg',
    },
    body: req.body,
    // @ts-ignore Deno fetch で stream body を送る場合に必要
    duplex: 'half',
  });

  if (!dgRes.ok) {
    const detail = await dgRes.text().catch(() => '');
    return jsonRes(req, {
      error: 'deepgram_failed',
      status: dgRes.status,
      detail: detail.slice(0, 500),
    }, 502);
  }

  const data = await dgRes.json();
  const alt = data?.results?.channels?.[0]?.alternatives?.[0];
  const paragraphs = (alt?.paragraphs?.transcript as string | undefined)?.trim();
  const transcript = paragraphs || (alt?.transcript as string | undefined)?.trim() || '';
  return jsonRes(req, { transcript }, 200);
});
