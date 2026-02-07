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
  output_language?: string;
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
    // 注: 言語が変わった場合は再生成が必要なので、キャッシュはスキップ
    console.log("=== CHECKING CACHE ===");
    console.log("Requested language:", body.output_language || "ja");
    console.log("Cache skipped - generating fresh summary for requested language");

    // OpenAI呼び出し
    console.log("=== CALLING OPENAI API ===");
    console.log("OPENAI_API_KEY exists:", !!Deno.env.get("OPENAI_API_KEY"));
    console.log("Output language:", body.output_language || "ja (default)");
    
    const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY") });

    // 言語名マッピング（より詳細な指示）
    const languageConfigs: Record<string, { name: string; instruction: string }> = {
      ja: { 
        name: "Japanese",
        instruction: "すべての出力は日本語で書いてください。summary、key_points、sections、questions、answersなど、すべてのテキストフィールドを日本語で記述してください。"
      },
      en: { 
        name: "English",
        instruction: "Write ALL output in English. All text fields including summary, key_points, sections, questions, and answers must be in English."
      },
      es: { 
        name: "Spanish",
        instruction: "Escribe TODA la salida en español. Todos los campos de texto, incluyendo resumen, puntos clave, secciones, preguntas y respuestas deben estar en español."
      },
      zh: { 
        name: "Chinese",
        instruction: "用中文写所有输出。所有文本字段，包括摘要、要点、部分、问题和答案都必须用中文。"
      },
      ko: { 
        name: "Korean",
        instruction: "모든 출력을 한국어로 작성하세요. 요약, 핵심 포인트, 섹션, 질문 및 답변을 포함한 모든 텍스트 필드는 한국어로 작성해야 합니다."
      },
      fr: { 
        name: "French",
        instruction: "Écrivez TOUTE la sortie en français. Tous les champs de texte, y compris le résumé, les points clés, les sections, les questions et les réponses doivent être en français."
      },
      de: { 
        name: "German",
        instruction: "Schreiben Sie die GESAMTE Ausgabe auf Deutsch. Alle Textfelder einschließlich Zusammenfassung, Schlüsselpunkte, Abschnitte, Fragen und Antworten müssen auf Deutsch sein."
      },
    };
    
    const outputLanguage = body.output_language || "ja";
    const langConfig = languageConfigs[outputLanguage] || languageConfigs["ja"];
    const languageName = langConfig.name;
    const languageInstruction = langConfig.instruction;

    let prompt: string;
    if (body.mode === "summary") {
      prompt = `IMPORTANT: ${languageInstruction}

Analyze the following lecture transcript and generate a summary in JSON format.
The lecture content is in English, but you MUST provide ALL output text in ${languageName}.

Lecture content:
${transcript.content}

Required JSON format:
{
  "summary": "Comprehensive summary in ${languageName} (200-300 characters)",
  "key_points": ["Key point 1 in ${languageName}", "Key point 2 in ${languageName}", "..."],
  "sections": [
    {"heading": "Section heading in ${languageName}", "content": "Section summary in ${languageName}"},
    "..."
  ]
}

Remember: ALL text values must be in ${languageName}!`;
    } else {
      prompt = `IMPORTANT: ${languageInstruction}

Analyze the following lecture transcript and generate exam preparation materials in JSON format.
The lecture content is in English, but you MUST provide ALL output text in ${languageName}.

Lecture content:
${transcript.content}

Required JSON format:
{
  "key_terms": [
    {"term": "Term in ${languageName}", "definition": "Definition in ${languageName}"},
    "..."
  ],
  "questions": [
    {"question": "Question in ${languageName}", "answer": "Answer in ${languageName}"},
    "..."
  ],
  "predictions": ["Prediction 1 in ${languageName}", "Prediction 2 in ${languageName}", "..."]
}

Remember: ALL text values (terms, definitions, questions, answers, predictions) must be in ${languageName}!`;
    }

    console.log("Creating OpenAI prompt for mode:", body.mode);
    console.log("Target language:", languageName);

    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        { 
          role: "system", 
          content: `You are an expert in summarizing university lectures and preparing exam materials. ${languageInstruction} Do NOT use English if the target language is not English.` 
        },
        { role: "user", content: prompt },
      ],
      response_format: { type: "json_object" },
      temperature: 0.3,
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
