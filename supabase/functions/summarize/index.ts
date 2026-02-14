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
    // 認証
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError) {
      return createErrorResponse(req, "Authentication failed", 401);
    }

    if (!user) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ホワイトリストチェック（環境変数から取得）
    const whitelistEmails = Deno.env.get("WHITELIST_EMAILS") || "";
    const whitelistedUsers = whitelistEmails.split(",").map(email => email.trim());
    const isWhitelisted = user.email && whitelistedUsers.includes(user.email);

    // ホワイトリストユーザーでない場合はPro状態チェック
    if (!isWhitelisted) {
      const { data: subscription } = await serviceClient
        .from("subscriptions")
        .select("status")
        .eq("user_id", user.id)
        .single();

      if (!subscription || subscription.status !== "active") {
        return createErrorResponse(req, "Pro subscription required", 403);
      }
    }

    // リクエスト
    const body: SummarizeRequest = await req.json();

    // フェアリミットチェック
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { count: dailyCount, error: countError } = await serviceClient
      .from("usage_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", today.toISOString());

    if (countError) {
      console.error("Usage count error:", countError.message);
    }

    if ((dailyCount || 0) >= DAILY_LIMIT) {
      return createErrorResponse(req, "Daily limit reached. Try again tomorrow.", 429);
    }

    // transcript取得（所有権チェック付き）
    const { data: transcript, error: transcriptError } = await serviceClient
      .from("transcripts")
      .select("id, content, title, user_id")
      .eq("id", body.transcript_id)
      .eq("user_id", user.id)
      .single();

    if (transcriptError || !transcript) {
      return createErrorResponse(req, "Transcript not found or access denied", 404);
    }

    // OpenAI呼び出し
    const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY") });

    // 言語名マッピング
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

    const result = JSON.parse(completion.choices[0].message.content || "{}");

    // 保存
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

    const { data: savedSummary, error: saveError } = await serviceClient
      .from("summaries")
      .upsert(summaryData, { onConflict: "transcript_id" })
      .select()
      .single();

    if (saveError) {
      console.error("Failed to save summary:", saveError.message);
      return createErrorResponse(req, "Internal server error", 500);
    }

    // 使用ログ記録
    const { error: logError } = await serviceClient.from("usage_logs").insert({
      user_id: user.id,
      action: body.mode === "summary" ? "summarize" : "exam_mode",
      transcript_id: body.transcript_id,
    });

    if (logError) {
      console.error("Failed to log usage:", logError.message);
    }

    return createJsonResponse(req, savedSummary);
  } catch (error) {
    console.error("Summarize error:", error instanceof Error ? error.message : "Unknown error");
    return createErrorResponse(req, "Internal server error", 500);
  }
});
