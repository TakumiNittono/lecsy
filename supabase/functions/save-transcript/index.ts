// supabase/functions/save-transcript/index.ts
// Purpose: iOSからの文字起こしテキスト保存

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';
import { alert } from '../_shared/alert.ts';

// 環境変数でデバッグモードを制御
const DEBUG_MODE = Deno.env.get("DEBUG") === "true";

function debugLog(...args: unknown[]): void {
  if (DEBUG_MODE) {
    console.log("[DEBUG]", ...args);
  }
}

function maskToken(token: string, visibleChars: number = 8): string {
  if (token.length <= visibleChars) {
    return "***";
  }
  return `${token.substring(0, visibleChars)}***[length:${token.length}]`;
}

interface SaveTranscriptRequest {
  title: string;
  content: string;
  created_at: string;
  duration?: number;
  language?: string;
  app_version?: string;
  // Local Lecture.id from iOS — used to dedupe on backfill retries.
  client_id?: string | null;
  // B2B context (optional). When the user has an active organization
  // membership, the iOS client passes these so the transcript becomes
  // visible according to the chosen visibility level.
  organization_id?: string | null;
  visibility?: 'private' | 'class' | 'org_wide' | null;
  // class_id は 2026-04-07 b2b_simplify で列削除済。iOS が古い版で送ってきても
  // 読み捨てるため型には残すが、insert には使わない。
  class_id?: string | null;
}

serve(async (req) => {
  // CORS プリフライト
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  // Sentry / Slack に送る診断コンテキスト。try/catch の両方から読めるよう外側に置く。
  // PII (content, title) は載せない。量・所属・dedup キー程度に限定。
  const diag: Record<string, unknown> = {};

  try {
    // 認証（summarize関数と完全に同じ実装）
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return createErrorResponse(req, "Unauthorized", 401);
    }
    diag.user_id = user.id;

    // リクエストボディ
    const body: SaveTranscriptRequest = await req.json();
    diag.content_length = body.content?.length ?? 0;
    diag.has_client_id = !!body.client_id;
    diag.has_org = !!body.organization_id;
    diag.visibility = body.visibility ?? null;
    diag.app_version = body.app_version ?? null;
    diag.language = body.language ?? null;

    // バリデーション
    if (!body.content || body.content.trim() === "") {
      return createErrorResponse(req, "Content is required", 400);
    }

    // word_count計算
    const wordCount = body.content.split(/\s+/).filter(Boolean).length;

    // B2B context: validate org membership before trusting the org_id
    let orgId: string | null = null;
    let visibility: string = 'private';
    if (body.organization_id) {
      const { data: membership } = await supabase
        .from('organization_members')
        .select('id')
        .eq('org_id', body.organization_id)
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();
      if (membership) {
        orgId = body.organization_id;
        if (body.visibility && ['private', 'class', 'org_wide'].includes(body.visibility)) {
          visibility = body.visibility;
        }
        // class_id / classes テーブルは 2026-04-07 b2b_simplify で削除済。
        // iOS 旧版から来ても無視して先に進む。
      }
    }

    // Idempotent path: if iOS sent a client_id and we already have a row
    // for (user_id, client_id), return the existing one instead of
    // inserting a duplicate. This makes backfill safely retryable.
    if (body.client_id) {
      const { data: existing } = await supabase
        .from("transcripts")
        .select("id, created_at")
        .eq("user_id", user.id)
        .eq("client_id", body.client_id)
        .maybeSingle();
      if (existing) {
        return createJsonResponse(req, existing);
      }
    }

    // 保存
    const { data, error } = await supabase
      .from("transcripts")
      .insert({
        user_id: user.id,
        title: body.title || `Recording ${new Date().toISOString()}`,
        content: body.content,
        created_at: body.created_at || new Date().toISOString(),
        duration: body.duration,
        language: body.language,
        word_count: wordCount,
        source: "ios",
        client_id: body.client_id ?? null,
        organization_id: orgId,
        visibility: visibility,
      })
      .select("id, created_at")
      .single();

    if (error) {
      throw error;
    }

    return createJsonResponse(req, data);
  } catch (error) {
    // Supabase / PostgREST が返す error は plain object (code / message / details / hint)
    // で instanceof Error が false になるケースがあり、以前は全部 "Unknown error" に
    // 畳まれて原因特定できなかった。型別に拾って Sentry / Slack / レスポンスに漏れなく渡す。
    const e = error as (Record<string, unknown> & Error) | undefined;
    const parts: string[] = [];
    if (e?.message && typeof e.message === 'string') parts.push(e.message);
    if (e?.code) parts.push(`code=${e.code}`);
    if (e?.details) parts.push(`details=${e.details}`);
    if (e?.hint) parts.push(`hint=${e.hint}`);
    const msg = parts.length > 0 ? parts.join(' | ') : String(error ?? 'Unknown error');

    console.error("save-transcript error:", msg, diag);
    await alert({
      source: 'save-transcript',
      level: 'error',
      message: `save_transcript_failed: ${msg}`,
      context: {
        ...diag,
        pg_code: e?.code ?? null,
        pg_details: e?.details ?? null,
        pg_hint: e?.hint ?? null,
      },
      error: error instanceof Error ? error : new Error(msg),
    });
    // iOS 側で Sentry に body が残るよう、500 レスポンスに detail を載せる。
    // PII にならないよう PostgrestError の構造フィールドだけを出す。
    return new Response(
      JSON.stringify({
        error: 'internal_server_error',
        detail: msg,
        code: e?.code ?? null,
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': req.headers.get('origin') ?? '*',
        },
      },
    );
  }
});
