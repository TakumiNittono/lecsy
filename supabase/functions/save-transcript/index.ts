// supabase/functions/save-transcript/index.ts
// Purpose: iOSからの文字起こしテキスト保存

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';

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
  class_id?: string | null;
}

serve(async (req) => {
  // CORS プリフライト
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

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

    // リクエストボディ
    const body: SaveTranscriptRequest = await req.json();

    // バリデーション
    if (!body.content || body.content.trim() === "") {
      return createErrorResponse(req, "Content is required", 400);
    }

    // word_count計算
    const wordCount = body.content.split(/\s+/).filter(Boolean).length;

    // B2B context: validate org membership before trusting the org_id
    let orgId: string | null = null;
    let visibility: string = 'private';
    let classId: string | null = null;
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
        // Validate class_id belongs to the same org before trusting it.
        if (body.class_id) {
          const { data: cls } = await supabase
            .from('classes')
            .select('id')
            .eq('id', body.class_id)
            .eq('org_id', orgId)
            .maybeSingle();
          if (cls) classId = body.class_id;
        }
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
        class_id: classId,
      })
      .select("id, created_at")
      .single();

    if (error) {
      throw error;
    }

    return createJsonResponse(req, data);
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : "Unknown error");
    return createErrorResponse(req, "Internal server error", 500);
  }
});
