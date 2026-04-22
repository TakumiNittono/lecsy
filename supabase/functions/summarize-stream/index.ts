// supabase/functions/summarize-stream/index.ts
// Streaming summary generation.
// Accepts transcript content directly (no pre-save step) and streams the
// OpenAI response back as plain-text chunks so the client can show partial
// results instantly while the model is still generating.
//
// Output format (markdown-like so partial parsing is trivial):
//   ## Summary
//   <paragraph>
//
//   ## Key Points
//   - point 1
//   - point 2
//
//   ## Sections
//   ### Heading
//   content
//
//   ### Heading
//   content

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createPreflightResponse, createErrorResponse, createJsonResponse } from "../_shared/cors.ts";
import { getLimits, buildRateLimitBody } from "../_shared/campaign.ts";
import { callOpenAIChat } from "../_shared/openai.ts";
import { alert } from "../_shared/alert.ts";

interface StreamRequest {
  content: string;
  title?: string;
  language?: string;
  output_language?: string;
}

// キャンペーン連動: 6/1 までは緩和上限, それ以降は通常上限。
// 数値は _shared/campaign.ts を参照。

const languageConfigs: Record<string, { name: string; instruction: string }> = {
  ja: { name: "Japanese", instruction: "すべての出力は日本語で書いてください。" },
  en: { name: "English", instruction: "Write ALL output in English." },
  es: { name: "Spanish", instruction: "Escribe TODA la salida en español." },
  zh: { name: "Chinese", instruction: "用中文写所有输出。" },
  ko: { name: "Korean", instruction: "모든 출력을 한국어로 작성하세요." },
  fr: { name: "French", instruction: "Écrivez TOUTE la sortie en français." },
  de: { name: "German", instruction: "Schreiben Sie die GESAMTE Ausgabe auf Deutsch." },
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return createErrorResponse(req, "Unauthorized", 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return createErrorResponse(req, "Unauthorized", 401);

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Rate limits (campaign-aware) — daily / monthly を並列に取得して往復時間を半減。
    // 旧実装は sequential で ~100-200ms かかっていた。
    const limits = getLimits();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const [dailyRes, monthlyRes] = await Promise.all([
      serviceClient
        .from("usage_logs")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user.id)
        .gte("created_at", today.toISOString()),
      serviceClient
        .from("usage_logs")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user.id)
        .gte("created_at", startOfMonth.toISOString()),
    ]);
    const dailyCount = dailyRes.count || 0;
    const monthlyCount = monthlyRes.count || 0;

    if (dailyCount >= limits.daily) {
      const resetAt = new Date(today);
      resetAt.setDate(resetAt.getDate() + 1);
      return createJsonResponse(
        req,
        buildRateLimitBody("daily", limits.daily, dailyCount, resetAt, limits),
        429,
      );
    }
    if (monthlyCount >= limits.monthly) {
      const resetAt = new Date(startOfMonth);
      resetAt.setMonth(resetAt.getMonth() + 1);
      return createJsonResponse(
        req,
        buildRateLimitBody("monthly", limits.monthly, monthlyCount, resetAt, limits),
        429,
      );
    }

    const body: StreamRequest = await req.json();
    if (!body.content || body.content.trim().length === 0) {
      return createErrorResponse(req, "Empty transcript content", 400);
    }

    // Server-side wallet guard. Anything over 100k chars is almost certainly
    // a client bug (Whisper hallucination, dedup failure, etc). Cap hard
    // before sending to OpenAI so a single buggy client can't burn through
    // the budget.
    const MAX_CONTENT_CHARS = 100_000;
    if (body.content.length > MAX_CONTENT_CHARS) {
      console.warn(`Truncating oversized transcript: ${body.content.length} chars`);
      body.content = body.content.slice(0, MAX_CONTENT_CHARS);
    }

    const outputLanguage = body.output_language || "en";
    const langConfig = languageConfigs[outputLanguage] || languageConfigs["en"];

    // Scale output by transcript length
    const wordCount = body.content.trim().split(/\s+/).length;
    let summaryTarget: string;
    let keyPointsRange: string;
    let sectionsRange: string;
    if (wordCount < 500) {
      summaryTarget = "150-250 characters";
      keyPointsRange = "3-5";
      sectionsRange = "2-3";
    } else if (wordCount < 2000) {
      summaryTarget = "300-500 characters";
      keyPointsRange = "5-8";
      sectionsRange = "3-5";
    } else if (wordCount < 5000) {
      summaryTarget = "500-800 characters";
      keyPointsRange = "7-12";
      sectionsRange = "5-8";
    } else {
      summaryTarget = "800-1200 characters";
      keyPointsRange = "10-15";
      sectionsRange = "6-10";
    }

    const systemPrompt = `You are an expert in summarizing university lectures. ${langConfig.instruction} Do NOT use English unless the target language is English.`;
    const userPrompt = `${langConfig.instruction}

Analyze the following lecture transcript (${wordCount} words) and write a structured summary. The lecture content is in English, but you MUST write ALL output in ${langConfig.name}.

CRITICAL: Keep the three section markers "## Summary", "## Key Points", and "## Sections" EXACTLY as written in English. DO NOT translate these headers. Only the content inside each section should be in ${langConfig.name}.

Use EXACTLY this markdown format — nothing before, nothing after:

## Summary
<A comprehensive summary in ${langConfig.name}, ${summaryTarget}. Cover ALL main points. Start directly with the substance — do NOT begin with meta phrases like "This lecture covers" / "今回の講義は" / "この講義では".>

## Key Points
- <${keyPointsRange} concrete takeaways, one per line>

## Sections
### <Section heading in ${langConfig.name}>
<Section summary in ${langConfig.name} — explain the actual content>

### <Section heading in ${langConfig.name}>
<Section summary in ${langConfig.name}>

(${sectionsRange} sections total, covering the full arc of the lecture)

Lecture content:
${body.content}`;

    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return createErrorResponse(req, "OPENAI_API_KEY not configured", 500);
    }

    // Call OpenAI Chat Completions API with streaming via retry helper.
    // ストリーミング API でも接続確立時の 429/503 はリトライ対象になる。
    // 一度接続が確立してストリーム中にエラーが起きた場合はリトライしない
    // (部分レスポンスの破棄が必要になるため)。
    const openaiResp = await callOpenAIChat({
      apiKey,
      body: {
        model: "gpt-5-nano",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        stream: true,
      },
    });

    if (!openaiResp.ok || !openaiResp.body) {
      const errText = await openaiResp.text().catch(() => "");
      console.error(`OpenAI API error ${openaiResp.status}: ${errText.slice(0, 500)}`);
      if (openaiResp.status === 429 || openaiResp.status === 503) {
        return createErrorResponse(req, "openai_busy_try_again", 503);
      }
      return createErrorResponse(req, `openai_api_error: ${openaiResp.status}`, 500);
    }

    // Log usage up-front (fire and forget).
    // usage_logs.action は CHECK 制約で ('summarize', 'exam_mode') のみ許容。
    // 以前 'summarize_stream' を入れて CHECK 違反で silent drop → ダッシュボードの
    // summaries_generated が常に 0 になっていた。レガシーと同じ 'summarize' に統一。
    serviceClient.from("usage_logs").insert({
      user_id: user.id,
      action: "summarize",
    }).then(({ error }: { error: unknown }) => {
      if (error) {
        console.error("usage_logs insert failed:", error);
      }
    }, (err: unknown) => {
      console.error("usage_logs insert rejected:", err);
    });

    // Parse OpenAI's SSE stream and forward the delta text to the client.
    // SSE format: `data: {json}\n\n`, and `data: [DONE]\n\n` at the end.
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();
    const stream = new ReadableStream({
      async start(controller) {
        const reader = openaiResp.body!.getReader();
        let buffer = "";
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const events = buffer.split("\n\n");
            buffer = events.pop() || "";
            for (const evt of events) {
              const line = evt.trim();
              if (!line.startsWith("data:")) continue;
              const payload = line.slice(5).trim();
              if (!payload || payload === "[DONE]") continue;
              try {
                const json = JSON.parse(payload);
                const delta = json?.choices?.[0]?.delta?.content;
                if (delta) {
                  controller.enqueue(encoder.encode(delta));
                }
              } catch (parseErr) {
                console.error("Failed to parse SSE payload:", parseErr, payload.slice(0, 200));
              }
            }
          }
          controller.close();
        } catch (err) {
          console.error("OpenAI stream error:", err);
          controller.error(err);
        }
      },
    });

    const corsHeaders: Record<string, string> = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-cache",
      "X-Accel-Buffering": "no",
    };

    return new Response(stream, { status: 200, headers: corsHeaders });
  } catch (error) {
    const msg = error instanceof Error ? error.message : "Unknown error";
    console.error("summarize-stream error:", msg);
    await alert({
      source: 'summarize-stream',
      level: 'error',
      message: `summarize_stream_failed: ${msg}`,
      error,
    });
    return createErrorResponse(req, `summarize_stream_failed: ${msg}`, 500);
  }
});
