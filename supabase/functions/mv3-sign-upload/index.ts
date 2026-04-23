// /mp3 ページ用 — 署名付きアップロード URL 発行 Edge Function
//
// 役割:
//   - PIN (MV3_PIN, default "0816") を timing-safe 比較で検証
//   - Supabase Storage `mv3-uploads` バケットに対し
//     createSignedUploadUrl() でブラウザが直接 PUT できる署名 URL を返す
//   - オブジェクト path は UUID ベースで衝突しない形に固定
//
// Edge Function の 10MB リクエストボディ制限を回避するための入口。
// 実際のアップロードはブラウザ → Supabase Storage が直接行う。
//
// 必要 env (Supabase Edge Functions で自動注入される): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// 必要 secrets: MV3_PIN

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.47.0';
import { timingSafeEqual } from 'https://deno.land/std@0.224.0/crypto/timing_safe_equal.ts';

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

function sanitizeExt(filename: string): string {
  const m = /\.([A-Za-z0-9]{1,5})$/.exec(filename);
  const ext = (m?.[1] ?? 'mp3').toLowerCase();
  const allowed = new Set(['mp3', 'm4a', 'mp4', 'wav']);
  return allowed.has(ext) ? ext : 'mp3';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== 'POST') {
    return jsonRes(req, { error: 'method_not_allowed' }, 405);
  }
  if (!pinOk(req.headers.get('x-mv3-pin'))) {
    return jsonRes(req, { error: 'unauthorized' }, 401);
  }

  let body: { filename?: string } = {};
  try {
    body = await req.json();
  } catch {
    // 空でも問題ない (filename は任意)
  }

  const ext = sanitizeExt(body.filename ?? '');
  const path = `uploads/${crypto.randomUUID()}.${ext}`;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data, error } = await supabase.storage
    .from('mv3-uploads')
    .createSignedUploadUrl(path);

  if (error || !data) {
    return jsonRes(req, {
      error: 'sign_failed',
      detail: error?.message?.slice(0, 300) ?? '',
    }, 500);
  }

  return jsonRes(req, {
    path: data.path,
    token: data.token,
    signedUrl: data.signedUrl,
  }, 200);
});
