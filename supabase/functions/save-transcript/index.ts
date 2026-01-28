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
    debugLog("Request received");
    
    // 認証チェック
    const authHeader = req.headers.get("Authorization");
    console.log("Authorization header present:", !!authHeader);
    
    if (!authHeader) {
      console.error("Authorization header is missing");
      return new Response(JSON.stringify({ error: "Unauthorized", code: "NO_AUTH_HEADER" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Bearerプレフィックスを確認
    if (!authHeader.startsWith("Bearer ")) {
      console.error("Invalid authorization format");
      return createErrorResponse(req, "Invalid auth format", 401);
    }

    // JWTトークンを抽出
    const token = authHeader.substring(7); // "Bearer "を除去
    debugLog("JWT token:", maskToken(token));

    // Supabaseクライアント
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    console.log("Supabase URL configured:", !!supabaseUrl);
    console.log("Supabase Anon Key configured:", !!supabaseAnonKey);
    
    const supabase = createClient(
      supabaseUrl!,
      supabaseAnonKey!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // ユーザー取得（JWT検証を含む）
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    console.log("User authenticated:", !!user);
    
    if (authError) {
      console.error("Auth error:", authError);
      console.error("Auth error details:", JSON.stringify(authError, null, 2));
      console.error("Auth error status:", authError.status);
      console.error("Auth error message:", authError.message);
      
      // JWT検証エラーの場合、より詳細な情報を返す
      if (authError.message && authError.message.includes("JWT")) {
        console.error("JWT validation failed. Token:", token.substring(0, 100));
        // JWTの有効期限を確認（デコードはしないが、形式を確認）
        const tokenParts = token.split(".");
        console.error("JWT parts count:", tokenParts.length);
        if (tokenParts.length === 3) {
          try {
            // JWTのペイロード部分をデコード（検証なし）
            const payload = JSON.parse(atob(tokenParts[1]));
            console.error("JWT payload:", JSON.stringify(payload, null, 2));
            console.error("JWT exp (expiration):", payload.exp);
            console.error("JWT exp (date):", new Date(payload.exp * 1000).toISOString());
            console.error("Current time:", new Date().toISOString());
            console.error("Token expired:", payload.exp < Date.now() / 1000);
          } catch (e) {
            console.error("Failed to decode JWT payload:", e);
          }
        }
      }
      
      return createErrorResponse(req, "Unauthorized", 401);
    }
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
