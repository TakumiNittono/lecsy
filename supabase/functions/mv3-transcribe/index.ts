// MP3 文字起こし用 Edge Function (母用 /mp3 ページ専用)
//
// 役割:
//   - PIN ゲート (MV3_PIN secret, default "0816") を timing-safe 比較で検証
//   - Supabase Storage `mv3-uploads` にアップロード済みの音声 path を JSON で受け取り、
//     service_role で署名付きダウンロード URL を発行
//   - Deepgram pre-recorded `/v1/listen` に URL モードで投げる
//     (リクエストボディに音声バイナリを載せないため、Edge Function の 10MB 制限を超える
//      長尺音声 — 2 時間講義 etc. — を処理できる)
//   - 完了後 Storage オブジェクトを削除して後始末
//
// 必要 secrets: DEEPGRAM_ADMIN_KEY, MV3_PIN
// Supabase が自動注入: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.47.0';
import { timingSafeEqual } from 'https://deno.land/std@0.224.0/crypto/timing_safe_equal.ts';

const DEEPGRAM_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY');
const EXPECTED_PIN = Deno.env.get('MV3_PIN') ?? '0816';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

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

  let body: { path?: string; language?: string } = {};
  try {
    body = await req.json();
  } catch {
    return jsonRes(req, { error: 'invalid_json' }, 400);
  }

  const path = body.path;
  if (!path || typeof path !== 'string' || !path.startsWith('uploads/')) {
    return jsonRes(req, { error: 'invalid_path' }, 400);
  }

  const langParam = body.language ?? 'ja';
  const language = ['ja', 'en', 'en-US'].includes(langParam) ? langParam : 'ja';

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Deepgram が URL から直接ダウンロードするための署名付き URL を 1 時間有効で生成
  const { data: signedData, error: signedErr } = await supabase.storage
    .from('mv3-uploads')
    .createSignedUrl(path, 3600);

  if (signedErr || !signedData) {
    return jsonRes(req, {
      error: 'sign_download_failed',
      detail: signedErr?.message?.slice(0, 300) ?? '',
    }, 500);
  }

  const params = new URLSearchParams({
    model: 'nova-2-general',
    language,
    smart_format: 'true',
    punctuate: 'true',
    paragraphs: 'true',
  });

  let transcript = '';
  let dgStatus = 0;
  let dgDetail = '';

  try {
    const dgRes = await fetch(`https://api.deepgram.com/v1/listen?${params.toString()}`, {
      method: 'POST',
      headers: {
        Authorization: `Token ${DEEPGRAM_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ url: signedData.signedUrl }),
    });

    dgStatus = dgRes.status;
    if (!dgRes.ok) {
      dgDetail = (await dgRes.text().catch(() => '')).slice(0, 500);
    } else {
      const data = await dgRes.json();
      const alt = data?.results?.channels?.[0]?.alternatives?.[0];
      const paragraphs = (alt?.paragraphs?.transcript as string | undefined)?.trim();
      transcript = paragraphs || (alt?.transcript as string | undefined)?.trim() || '';
    }
  } finally {
    // 成否に関わらずアップロード物は削除 (個人情報を置き去りにしない)
    await supabase.storage.from('mv3-uploads').remove([path]).catch(() => {});
  }

  if (!transcript && dgStatus && dgStatus !== 200) {
    return jsonRes(req, {
      error: 'deepgram_failed',
      status: dgStatus,
      detail: dgDetail,
    }, 502);
  }

  return jsonRes(req, { transcript }, 200);
});
