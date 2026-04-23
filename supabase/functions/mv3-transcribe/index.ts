// MP3 文字起こし用 Edge Function (母用 /mv3 ページ専用)
//
// 設計:
//   - PIN ゲート (MV3_PIN secret, default "0816") を timing-safe 比較で検証
//   - Deepgram pre-recorded REST `/v1/listen` に音声を pass-through
//   - JWT 不要 (config.toml で verify_jwt = false)
//   - Browser から直接呼ばれるため CORS は www.lecsy.app / lecsy.app を許可
//
// 必要 secrets: DEEPGRAM_ADMIN_KEY (既存), MV3_PIN (新規)

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

  const url = new URL(req.url);
  const langParam = url.searchParams.get('language') ?? 'ja';
  const language = ['ja', 'en', 'en-US'].includes(langParam) ? langParam : 'ja';

  const audio = await req.arrayBuffer();
  if (audio.byteLength === 0) {
    return jsonRes(req, { error: 'no_body' }, 400);
  }

  const params = new URLSearchParams({
    model: 'nova-2-general',
    language,
    smart_format: 'true',
    punctuate: 'true',
    paragraphs: 'true',
  });

  const dgRes = await fetch(`https://api.deepgram.com/v1/listen?${params.toString()}`, {
    method: 'POST',
    headers: {
      Authorization: `Token ${DEEPGRAM_KEY}`,
      'Content-Type': req.headers.get('content-type') ?? 'audio/mpeg',
    },
    body: audio,
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
