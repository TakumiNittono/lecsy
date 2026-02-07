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
