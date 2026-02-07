// supabase/functions/summarize/index.ts
// Purpose: AI要約生成（Pro専用）

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import OpenAI from "https://esm.sh/openai@4";
import { decode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';

interface SummarizeRequest {
  transcript_id: string;
  mode: "summary" | "exam";
}

const DAILY_LIMIT = 20;
const MONTHLY_LIMIT = 400;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // 認証
    const authHeader = req.headers.get("Authorization");
    console.log("Authorization header received:", authHeader ? "Yes" : "No");
    
    if (!authHeader) {
      console.error("No Authorization header");
      return createErrorResponse(req, "Unauthorized: No auth header", 401);
    }

    // トークンを抽出
    const token = authHeader.replace("Bearer ", "");
    console.log("Token extracted, length:", token.length);

    // JWTをデコードしてユーザー情報を取得
    let userId: string;
    let userEmail: string | undefined;
    
    try {
      const parts = token.split('.');
      if (parts.length !== 3) {
        throw new Error('Invalid JWT format');
      }
      
      const payload = JSON.parse(new TextDecoder().decode(decode(parts[1])));
      userId = payload.sub;
      userEmail = payload.email;
      
      console.log("User from JWT:", userId, userEmail);
    } catch (jwtError) {
      console.error("JWT decode error:", jwtError);
      return createErrorResponse(req, "Invalid token", 401);
    }

    if (!userId) {
      return createErrorResponse(req, "No user ID in token", 401);
    }

    // Service Clientでユーザー情報を取得
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    console.log("Fetching user data from database...");

    console.log("Fetching user data from database...");

    // ホワイトリストチェック（環境変数から取得）
    const whitelistEmails = Deno.env.get("WHITELIST_EMAILS") || "";
    const whitelistedUsers = whitelistEmails.split(",").map(email => email.trim());
    const isWhitelisted = userEmail && whitelistedUsers.includes(userEmail);

    console.log("Whitelist check:", userEmail, "->", isWhitelisted);

    // ホワイトリストユーザーでない場合はPro状態チェック
    if (!isWhitelisted) {
      const { data: subscription } = await serviceClient
        .from("subscriptions")
        .select("status")
        .eq("user_id", userId)
        .single();

      if (!subscription || subscription.status !== "active") {
        console.log("User not Pro:", userId);
        return createErrorResponse(req, "Pro subscription required", 403);
      }
      console.log("User is Pro:", userId);
    } else {
      console.log(`[Whitelisted user] ${userEmail} - skipping Pro check`);
    }

    // リクエスト
    const body: SummarizeRequest = await req.json();

    // フェアリミットチェック
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { count: dailyCount } = await serviceClient
      .from("usage_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", today.toISOString());

    if ((dailyCount || 0) >= DAILY_LIMIT) {
      return createErrorResponse(req, "Daily limit reached. Try again tomorrow.", 429);
    }

    // transcript取得（所有権チェック付き）
    const { data: transcript, error: transcriptError } = await serviceClient
      .from("transcripts")
      .select("id, content, title, user_id")
      .eq("id", body.transcript_id)
      .eq("user_id", userId)  // 所有権チェックを追加
      .single();

    if (transcriptError || !transcript) {
      // 存在しない場合も権限がない場合も同じエラーを返す（情報漏洩防止）
      return createErrorResponse(req, "Transcript not found or access denied", 404);
    }

    // キャッシュチェック（所有権チェック付き）
    const { data: existingSummary } = await serviceClient
      .from("summaries")
      .select("*")
      .eq("transcript_id", body.transcript_id)
      .eq("user_id", userId)  // 所有権チェックを追加
      .single();

    if (existingSummary) {
      if (body.mode === "summary" && existingSummary.summary) {
        return createJsonResponse(req, existingSummary);
      }
      if (body.mode === "exam" && existingSummary.exam_mode) {
        return createJsonResponse(req, existingSummary);
      }
    }

    // OpenAI呼び出し
    const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY") });

    let prompt: string;
    if (body.mode === "summary") {
      prompt = `以下の講義文字起こしを分析し、JSON形式で要約を生成してください。

講義内容:
${transcript.content}

出力形式:
{
  "summary": "全体の要約（200-300文字）",
  "key_points": ["重要ポイント1", "重要ポイント2", ...],
  "sections": [
    {"heading": "セクション名", "content": "1行要約"},
    ...
  ]
}`;
    } else {
      prompt = `以下の講義文字起こしを分析し、試験対策用のJSON形式で情報を生成してください。

講義内容:
${transcript.content}

出力形式:
{
  "key_terms": [
    {"term": "用語", "definition": "定義"},
    ...
  ],
  "questions": [
    {"question": "問題", "answer": "解答"},
    ...
  ],
  "predictions": ["出題予想1", "出題予想2", ...]
}`;
    }

    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        { role: "system", content: "あなたは大学講義の要約と試験対策を行う専門家です。" },
        { role: "user", content: prompt },
      ],
      response_format: { type: "json_object" },
    });

    const result = JSON.parse(completion.choices[0].message.content || "{}");

    // 保存
    const summaryData = {
      transcript_id: body.transcript_id,
      user_id: userId,
      model: "gpt-4-turbo",
      ...(body.mode === "summary"
        ? {
            summary: result.summary,
            key_points: result.key_points,
            sections: result.sections,
          }
        : { exam_mode: result }),
    };

    const { data: savedSummary, error: saveError } = await serviceClient
      .from("summaries")
      .upsert(summaryData, { onConflict: "transcript_id" })
      .select()
      .single();

    if (saveError) throw saveError;

    // 使用ログ記録
    await serviceClient.from("usage_logs").insert({
      user_id: userId,
      action: body.mode === "summary" ? "summarize" : "exam_mode",
      transcript_id: body.transcript_id,
    });

    return createJsonResponse(req, savedSummary);
  } catch (error) {
    console.error("Error:", error);
    return createErrorResponse(req, "Internal server error", 500);
  }
});
