// supabase/functions/summarize/index.ts
// Purpose: AI要約生成
//
// Access policy (2026-04-09): 「5/31まで全機能無料開放」特別企画実施中。
//   - 認証済みユーザーなら誰でも利用可。
//   - キャンペーン期間中はレート上限を緩和 (50/day, 1500/month)。
//   - 6/1 を過ぎると自動的に通常上限 (20/day, 400/month) に戻る。
//     → _shared/campaign.ts を参照。コード変更不要。
//
// 本番耐性:
//   - OpenAI は _shared/openai.ts 経由で呼ぶ(指数バックオフ付き)。
//   - 同じ transcript+mode の直近要約が既にあれば OpenAI を呼ばずに
//     そのまま返す(クライアント再送時の課金暴走を防ぐ idempotency)。
//   - 429 は残数/リセット時刻付きの構造化 JSON で返す。

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';
import { getLimits, buildRateLimitBody } from '../_shared/campaign.ts';
import { callOpenAIChat } from '../_shared/openai.ts';
import { alert } from '../_shared/alert.ts';

interface SummarizeRequest {
  transcript_id: string;
  mode: "summary" | "exam_mode";
  output_language?: string;
}

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

    // 組織メンバーシップのゲートは撤廃。
    // サインイン済みなら誰でも要約を呼べる。濫用防止は下のレートリミットで行う。

    // リクエスト
    const body: SummarizeRequest = await req.json();

    // --- Idempotency guard ---------------------------------------------
    // 同じ transcript+mode で直近 10 分以内に生成済みの要約があれば、
    // OpenAI を呼ばずそのまま返す。クライアントのリトライや連打による
    // 二重課金を防ぐ。regenerate したい場合は 10 分待つか別 mode。
    {
      const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
      const { data: existing } = await serviceClient
        .from("summaries")
        .select("*")
        .eq("transcript_id", body.transcript_id)
        .eq("user_id", user.id)
        .gte("updated_at", tenMinAgo)
        .maybeSingle();
      if (existing) {
        const hasSummary = body.mode === "summary"
          ? existing.summary != null
          : existing.exam_mode != null;
        if (hasSummary) {
          console.log(`idempotent hit: transcript=${body.transcript_id} mode=${body.mode}`);
          return createJsonResponse(req, existing);
        }
      }
    }

    // --- Rate limits (campaign-aware) ----------------------------------
    const limits = getLimits();

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

    if ((dailyCount || 0) >= limits.daily) {
      const resetAt = new Date(today);
      resetAt.setDate(resetAt.getDate() + 1);
      return createJsonResponse(
        req,
        buildRateLimitBody("daily", limits.daily, dailyCount || 0, resetAt, limits),
        429,
      );
    }

    // 月間リミットチェック
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const { count: monthlyCount, error: monthlyCountError } = await serviceClient
      .from("usage_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", startOfMonth.toISOString());

    if (monthlyCountError) {
      console.error("Monthly usage count error:", monthlyCountError.message);
    }

    if ((monthlyCount || 0) >= limits.monthly) {
      const resetAt = new Date(startOfMonth);
      resetAt.setMonth(resetAt.getMonth() + 1);
      return createJsonResponse(
        req,
        buildRateLimitBody("monthly", limits.monthly, monthlyCount || 0, resetAt, limits),
        429,
      );
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

    // Wallet guard — cap oversized transcripts before they hit OpenAI.
    const MAX_CONTENT_CHARS = 100_000;
    if (transcript.content && transcript.content.length > MAX_CONTENT_CHARS) {
      console.warn(`Truncating oversized transcript: ${transcript.content.length} chars`);
      transcript.content = transcript.content.slice(0, MAX_CONTENT_CHARS);
    }

    // OpenAI gpt-5-nano 呼び出し
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return createErrorResponse(req, "OPENAI_API_KEY not configured", 500);
    }

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

    const outputLanguage = body.output_language || "en";
    const langConfig = languageConfigs[outputLanguage] || languageConfigs["en"];
    const languageName = langConfig.name;
    const languageInstruction = langConfig.instruction;

    // トランスクリプト長に応じて要約のボリュームを可変にする。
    // 目安: transcript word count → summary char count / key_points / sections
    const wordCount = transcript.content.trim().split(/\s+/).length;
    let summaryCharRange: string;
    let keyPointsRange: string;
    let sectionsRange: string;
    if (wordCount < 500) {
      // ~3分未満の短い講義
      summaryCharRange = "150-250 characters";
      keyPointsRange = "3-5 key points";
      sectionsRange = "2-3 sections";
    } else if (wordCount < 2000) {
      // 3-15分
      summaryCharRange = "300-500 characters";
      keyPointsRange = "5-8 key points";
      sectionsRange = "3-5 sections";
    } else if (wordCount < 5000) {
      // 15-40分
      summaryCharRange = "500-800 characters";
      keyPointsRange = "7-12 key points";
      sectionsRange = "5-8 sections";
    } else {
      // 40分以上の長尺講義
      summaryCharRange = "800-1200 characters";
      keyPointsRange = "10-15 key points";
      sectionsRange = "6-10 sections";
    }

    let prompt: string;
    if (body.mode === "summary") {
      prompt = `IMPORTANT: ${languageInstruction}

Analyze the following lecture transcript and generate a summary in JSON format.
The lecture content is in English, but you MUST provide ALL output text in ${languageName}.

This transcript contains approximately ${wordCount} words. Scale the depth of the summary accordingly — do NOT compress a long lecture into a tiny summary, and do NOT inflate a short clip. Capture every main point thoroughly; it is better to be comprehensive than terse.

Lecture content:
${transcript.content}

Required JSON format:
{
  "summary": "Comprehensive summary in ${languageName} (${summaryCharRange}). Cover ALL main points from the lecture. Start directly with the content. DO NOT begin with meta phrases like 今回の講義は / この講義では / Today's lecture is / This lecture covers — just state the substance.",
  "key_points": ["${keyPointsRange} — each should be a concrete, substantive takeaway, not a vague heading"],
  "sections": [
    {"heading": "Section heading in ${languageName}", "content": "Section summary in ${languageName} — explain the actual content, not just name it"},
    "... ${sectionsRange} total, covering the full arc of the lecture"
  ]
}

Remember: ALL text values must be in ${languageName}! Capture the main points thoroughly.`;
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

    const openaiResp = await callOpenAIChat({
      apiKey,
      body: {
        model: "gpt-5-nano",
        messages: [
          { role: "system", content: `You are an expert in summarizing university lectures and preparing exam materials. ${languageInstruction} Do NOT use English if the target language is not English.` },
          { role: "user", content: prompt },
        ],
        response_format: { type: "json_object" },
      },
    });

    if (!openaiResp.ok) {
      const errText = await openaiResp.text();
      console.error(`OpenAI API error ${openaiResp.status}: ${errText.slice(0, 500)}`);
      // 429 はクライアントに "後で試して" とはっきり伝える
      if (openaiResp.status === 429 || openaiResp.status === 503) {
        return createErrorResponse(req, "openai_busy_try_again", 503);
      }
      return createErrorResponse(req, `openai_api_error: ${openaiResp.status}`, 500);
    }
    const openaiJson = await openaiResp.json();
    const responseText = openaiJson?.choices?.[0]?.message?.content ?? "{}";
    let result: Record<string, unknown> = {};
    try {
      result = JSON.parse(responseText);
    } catch (parseErr) {
      // response_format: json_object を付けているのでここに来るのは異常系。
      // malformed な生テキストを summary に詰めて返すと iOS 側で「ゴミ要約」が
      // 保存されてしまうので、ここは 502 で落としてユーザーに再試行させる。
      console.error("Failed to parse OpenAI JSON response:", parseErr, responseText.slice(0, 200));
      await alert({
        source: 'summarize',
        level: 'error',
        message: 'OpenAI returned non-JSON response in JSON mode',
        context: { user_id: user.id, transcript_id: body.transcript_id, preview: responseText.slice(0, 200) },
      });
      return createErrorResponse(req, 'openai_malformed_response', 502);
    }

    // 保存
    const summaryData = {
      transcript_id: body.transcript_id,
      user_id: user.id,
      model: "gpt-5-nano",
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
    const msg = error instanceof Error ? error.message : "Unknown error";
    console.error("Summarize error:", msg);
    await alert({
      source: 'summarize',
      level: 'error',
      message: `summarize_failed: ${msg}`,
      error,
    });
    return createErrorResponse(req, `summarize_failed: ${msg}`, 500);
  }
});
