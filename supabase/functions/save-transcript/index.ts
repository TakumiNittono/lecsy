// supabase/functions/save-transcript/index.ts
// Purpose: iOSからの文字起こしテキスト保存

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface SaveTranscriptRequest {
  title: string;
  content: string;
  created_at: string;
  duration?: number;
  language?: string;
  app_version?: string;
}

serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    // デバッグ: すべてのヘッダーをログ出力
    console.log("Request headers:", Object.fromEntries(req.headers.entries()));
    
    // 認証チェック
    const authHeader = req.headers.get("Authorization");
    console.log("Authorization header:", authHeader ? `${authHeader.substring(0, 50)}...` : "missing");
    console.log("Authorization header length:", authHeader ? authHeader.length : 0);
    
    if (!authHeader) {
      console.error("Authorization header is missing");
      return new Response(JSON.stringify({ error: "Unauthorized", code: "NO_AUTH_HEADER" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Bearerプレフィックスを確認
    if (!authHeader.startsWith("Bearer ")) {
      console.error("Authorization header does not start with 'Bearer '");
      return new Response(JSON.stringify({ error: "Unauthorized", code: "INVALID_AUTH_FORMAT" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // JWTトークンを抽出
    const token = authHeader.substring(7); // "Bearer "を除去
    console.log("JWT token (first 50 chars):", token.substring(0, 50));
    console.log("JWT token length:", token.length);

    // Supabaseクライアント
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    console.log("Supabase URL:", supabaseUrl);
    console.log("Supabase Anon Key (first 20 chars):", supabaseAnonKey ? `${supabaseAnonKey.substring(0, 20)}...` : "missing");
    
    const supabase = createClient(
      supabaseUrl!,
      supabaseAnonKey!,
      { global: { headers: { Authorization: authHeader } } }
    );

    console.log("Calling supabase.auth.getUser()...");
    // ユーザー取得（JWT検証を含む）
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    console.log("getUser result - user:", user ? user.id : "null", "error:", authError);
    
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
      
      return new Response(
        JSON.stringify({ 
          error: "Unauthorized", 
          code: "AUTH_ERROR",
          message: authError.message || "Authentication failed",
          details: authError.status ? `Status: ${authError.status}` : undefined
        }), 
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
    if (!user) {
      return new Response(
        JSON.stringify({ 
          error: "Unauthorized", 
          code: "NO_USER",
          message: "User not found"
        }), 
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // リクエストボディ
    const body: SaveTranscriptRequest = await req.json();

    // バリデーション
    if (!body.content || body.content.trim() === "") {
      return new Response(
        JSON.stringify({ error: "Content is required", code: "VALIDATION_ERROR" }),
        { 
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
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

    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        code: "INTERNAL_ERROR",
        message: errorMessage
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
