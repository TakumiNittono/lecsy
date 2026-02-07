// supabase/functions/summarize/index.ts
// Purpose: AI要約生成（Pro専用）

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import OpenAI from "https://esm.sh/openai@4";
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
    console.log("=== SUMMARIZE FUNCTION STARTED ===");
    console.log("Request method:", req.method);
    console.log("Request URL:", req.url);
    
    // 認証
    const authHeader = req.headers.get("Authorization");
    console.log("Authorization header exists:", !!authHeader);
    
    if (!authHeader) {
      console.error("ERROR: No Authorization header");
      return createErrorResponse(req, "Unauthorized: No auth header", 401);
    }

    console.log("Creating Supabase client...");
    console.log("SUPABASE_URL:", Deno.env.get("SUPABASE_URL") ? "Set" : "Missing");
    console.log("SUPABASE_ANON_KEY:", Deno.env.get("SUPABASE_ANON_KEY") ? "Set" : "Missing");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    console.log("Calling supabase.auth.getUser()...");
    const getUserResult = await supabase.auth.getUser();
    console.log("getUser result:", {
      hasData: !!getUserResult.data,
      hasUser: !!getUserResult.data?.user,
      hasError: !!getUserResult.error,
      errorMessage: getUserResult.error?.message
    });

    const { data: { user }, error: userError } = getUserResult;
    
    if (userError) {
      console.error("ERROR: getUser failed:", userError.message);
      return createErrorResponse(req, `Auth error: ${userError.message}`, 401);
    }
    
    if (!user) {
      console.error("ERROR: No user in response");
      return createErrorResponse(req, "Unauthorized: No user", 401);
    }

    console.log("✅ User authenticated:", user.id);
    console.log("User email:", user.email);

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    console.log("=== CHECKING WHITELIST ===");

    console.log("=== CHECKING WHITELIST ===");

    // ホワイトリストチェック（環境変数から取得）
    const whitelistEmails = Deno.env.get("WHITELIST_EMAILS") || "";
    console.log("WHITELIST_EMAILS env var:", whitelistEmails ? "Set" : "Not set");
    console.log("Whitelist value:", whitelistEmails);
    
    const whitelistedUsers = whitelistEmails.split(",").map(email => email.trim());
    console.log("Whitelisted users:", JSON.stringify(whitelistedUsers));
    
    const isWhitelisted = user.email && whitelistedUsers.includes(user.email);
    console.log("User email:", user.email);
    console.log("Is whitelisted:", isWhitelisted);

    // ホワイトリストユーザーでない場合はPro状態チェック
    if (!isWhitelisted) {
      console.log("=== CHECKING PRO STATUS ===");
      const { data: subscription, error: subError } = await serviceClient
        .from("subscriptions")
        .select("status")
        .eq("user_id", user.id)
        .single();

      console.log("Subscription query error:", subError?.message || "none");
      console.log("Subscription status:", subscription?.status || "none");

      if (!subscription || subscription.status !== "active") {
        console.log("ERROR: User not Pro");
        return createErrorResponse(req, "Pro subscription required", 403);
      }
      console.log("✅ User is Pro");
    } else {
      console.log(`✅ [Whitelisted user] ${user.email} - skipping Pro check`);
    }

    console.log("=== AUTHORIZATION SUCCESS ===");

    // リクエスト
    console.log("Parsing request body...");
    const body: SummarizeRequest = await req.json();
    console.log("Request body:", JSON.stringify(body));

    // フェアリミットチェック
    console.log("=== CHECKING USAGE LIMIT ===");
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { count: dailyCount, error: countError } = await serviceClient
      .from("usage_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", today.toISOString());

    console.log("Count error:", countError?.message || "none");
    console.log("Daily count:", dailyCount || 0);

    if ((dailyCount || 0) >= DAILY_LIMIT) {
      console.log("ERROR: Daily limit reached");
      return createErrorResponse(req, "Daily limit reached. Try again tomorrow.", 429);
    }
    console.log("✅ Usage limit OK");

    // transcript取得（所有権チェック付き）
    console.log("=== FETCHING TRANSCRIPT ===");
    console.log("Transcript ID:", body.transcript_id);
    
    const { data: transcript, error: transcriptError } = await serviceClient
      .from("transcripts")
      .select("id, content, title, user_id")
      .eq("id", body.transcript_id)
      .eq("user_id", user.id)  // 所有権チェックを追加
      .single();

    console.log("Transcript error:", transcriptError?.message || "none");
    console.log("Transcript found:", !!transcript);
    console.log("Transcript content length:", transcript?.content?.length || 0);

    if (transcriptError || !transcript) {
      console.log("ERROR: Transcript not found");
      // 存在しない場合も権限がない場合も同じエラーを返す（情報漏洩防止）
      return createErrorResponse(req, "Transcript not found or access denied", 404);
    }
    console.log("✅ Transcript retrieved");

    // キャッシュチェック（所有権チェック付き）
    console.log("=== CHECKING CACHE ===");
    const { data: existingSummary, error: cacheError } = await serviceClient
      .from("summaries")
      .select("*")
      .eq("transcript_id", body.transcript_id)
      .eq("user_id", user.id)  // 所有権チェックを追加
      .single();

    console.log("Cache error:", cacheError?.message || "none");
    console.log("Existing summary found:", !!existingSummary);

    if (existingSummary) {
      if (body.mode === "summary" && existingSummary.summary) {
        console.log("✅ Returning cached summary");
        return createJsonResponse(req, existingSummary);
      }
      if (body.mode === "exam" && existingSummary.exam_mode) {
        console.log("✅ Returning cached exam mode");
        return createJsonResponse(req, existingSummary);
      }
    }

    // OpenAI呼び出し
    console.log("=== CALLING OPENAI API ===");
    console.log("OPENAI_API_KEY exists:", !!Deno.env.get("OPENAI_API_KEY"));
    
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

    console.log("Creating OpenAI prompt for mode:", body.mode);

    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        { role: "system", content: "あなたは大学講義の要約と試験対策を行う専門家です。" },
        { role: "user", content: prompt },
      ],
      response_format: { type: "json_object" },
    });

    console.log("✅ OpenAI API call successful");
    console.log("Response length:", completion.choices[0].message.content?.length || 0);

    const result = JSON.parse(completion.choices[0].message.content || "{}");

    // 保存
    console.log("=== SAVING SUMMARY ===");
    const summaryData = {
      transcript_id: body.transcript_id,
      user_id: user.id,
      model: "gpt-4-turbo",
      ...(body.mode === "summary"
        ? {
            summary: result.summary,
            key_points: result.key_points,
            sections: result.sections,
          }
        : { exam_mode: result }),
    };

    console.log("Upserting summary data...");
    const { data: savedSummary, error: saveError } = await serviceClient
      .from("summaries")
      .upsert(summaryData, { onConflict: "transcript_id" })
      .select()
      .single();

    if (saveError) {
      console.error("ERROR: Failed to save summary:", saveError.message);
      throw saveError;
    }
    console.log("✅ Summary saved");

    // 使用ログ記録
    console.log("=== RECORDING USAGE ===");
    const { error: logError } = await serviceClient.from("usage_logs").insert({
      user_id: user.id,
      action: body.mode === "summary" ? "summarize" : "exam_mode",
      transcript_id: body.transcript_id,
    });

    if (logError) {
      console.error("WARNING: Failed to log usage:", logError.message);
    } else {
      console.log("✅ Usage logged");
    }

    console.log("=== SUCCESS - RETURNING RESPONSE ===");
    return createJsonResponse(req, savedSummary);
  } catch (error) {
    console.error("=== FATAL ERROR ===");
    console.error("Error type:", error?.constructor?.name);
    console.error("Error message:", error instanceof Error ? error.message : String(error));
    console.error("Error stack:", error instanceof Error ? error.stack : "No stack");
    return createErrorResponse(req, "Internal server error", 500);
  }
});
