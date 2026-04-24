// supabase/functions/org-ai-assist/index.ts
// Purpose: B2B専用AIアシスト（組織メンバー限定）
// Features: 多言語クロス要約 / カスタム用語集生成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import OpenAI from "https://esm.sh/openai@4";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';
import { alert } from '../_shared/alert.ts';

// ========== 型定義 ==========

interface CrossSummaryRequest {
  mode: "cross_summary";
  transcript_id: string;
  target_language: string;  // 出力言語コード（ja, en, es, zh, ko, fr, de...）
}

interface GlossaryGenerateRequest {
  mode: "glossary_generate";
  transcript_id: string;
  target_language?: string;  // 用語の説明言語（デフォルト: en）
  category?: string;         // カテゴリタグ
}

type OrgAiRequest = CrossSummaryRequest | GlossaryGenerateRequest;

// プラン別日次リミット
const PLAN_DAILY_LIMITS: Record<string, number> = {
  starter: 10,
  growth: 50,
  enterprise: 200,
};

// 言語名マッピング
const LANGUAGE_NAMES: Record<string, string> = {
  ja: "Japanese", en: "English", es: "Spanish", zh: "Chinese",
  ko: "Korean", fr: "French", de: "German", pt: "Portuguese",
  it: "Italian", ru: "Russian", ar: "Arabic", hi: "Hindi",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // ========== 認証 ==========
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
    if (userError || !user) {
      return createErrorResponse(req, "Authentication failed", 401);
    }

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ========== リクエスト解析 ==========
    const body: OrgAiRequest = await req.json();

    if (!body.mode || !body.transcript_id) {
      return createErrorResponse(req, "mode and transcript_id are required", 400);
    }

    // ========== 組織メンバーシップ確認 ==========
    // ユーザーが所属する組織を取得（active メンバーのみ）
    const { data: membership, error: memberError } = await serviceClient
      .from("organization_members")
      .select("org_id, role, organizations(id, name, slug, plan)")
      .eq("user_id", user.id)
      .eq("status", "active")
      .limit(1)
      .single();

    if (memberError || !membership) {
      return createErrorResponse(req, "Organization membership required. This feature is available only for B2B organization members.", 403);
    }

    const org = (membership as any).organizations;
    const orgId = membership.org_id;
    const orgPlan = org.plan;

    // ========== プラン別リミットチェック ==========
    const dailyLimit = PLAN_DAILY_LIMITS[orgPlan] || PLAN_DAILY_LIMITS.starter;

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { count: dailyCount } = await serviceClient
      .from("org_ai_usage_logs")
      .select("*", { count: "exact", head: true })
      .eq("org_id", orgId)
      .gte("created_at", today.toISOString());

    if ((dailyCount || 0) >= dailyLimit) {
      return createErrorResponse(
        req,
        `Organization daily AI limit reached (${dailyLimit}/day on ${orgPlan} plan). Upgrade your plan for higher limits.`,
        429
      );
    }

    // ========== トランスクリプト取得 ==========
    // 組織メンバーのトランスクリプトへのアクセス: 自分のもの、または同組織メンバーのもの
    const { data: orgMembers } = await serviceClient
      .from("organization_members")
      .select("user_id")
      .eq("org_id", orgId)
      .eq("status", "active");

    const orgUserIds = orgMembers?.map(m => m.user_id) || [];

    const { data: transcript, error: transcriptError } = await serviceClient
      .from("transcripts")
      .select("id, content, title, user_id, language")
      .eq("id", body.transcript_id)
      .in("user_id", orgUserIds)
      .single();

    if (transcriptError || !transcript) {
      return createErrorResponse(req, "Transcript not found or access denied", 404);
    }

    // ========== OpenAI呼び出し ==========
    const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY") });

    let result: any;
    let action: string;

    if (body.mode === "cross_summary") {
      result = await handleCrossSummary(openai, transcript, body.target_language);
      action = "cross_summary";
    } else if (body.mode === "glossary_generate") {
      result = await handleGlossaryGenerate(
        openai, transcript, body.target_language || "en", body.category
      );
      action = "glossary_generate";

      // 用語集をDBに保存
      if (result.terms && result.terms.length > 0) {
        const glossaryRows = result.terms.map((t: any) => ({
          org_id: orgId,
          term: t.term,
          definition: t.definition,
          language: body.target_language || "en",
          category: body.category || null,
          source_transcript_id: transcript.id,
          created_by: user.id,
        }));

        const { error: upsertError } = await serviceClient
          .from("org_glossaries")
          .upsert(glossaryRows, { onConflict: "org_id,term,language" });

        if (upsertError) {
          console.error("Failed to save glossary:", upsertError.message);
        } else {
          result.saved_count = glossaryRows.length;
        }
      }
    } else {
      return createErrorResponse(req, "Invalid mode. Use 'cross_summary' or 'glossary_generate'", 400);
    }

    // ========== 使用ログ記録 ==========
    await serviceClient.from("org_ai_usage_logs").insert({
      org_id: orgId,
      user_id: user.id,
      action,
      transcript_id: transcript.id,
      metadata: {
        target_language: body.mode === "cross_summary" ? body.target_language : (body.target_language || "en"),
        org_plan: orgPlan,
      },
    });

    return createJsonResponse(req, {
      ...result,
      org: { name: org.name, plan: orgPlan },
    });

  } catch (error) {
    const msg = error instanceof Error ? error.message : "Unknown error";
    console.error("org-ai-assist error:", msg);
    await alert({
      source: 'org-ai-assist',
      level: 'error',
      message: `org_ai_assist_failed: ${msg}`,
      error,
    });
    return createErrorResponse(req, "Internal server error", 500);
  }
});

// ========== 多言語クロス要約 ==========
async function handleCrossSummary(
  openai: OpenAI,
  transcript: { content: string; title: string; language: string | null },
  targetLanguage: string
) {
  const targetLangName = LANGUAGE_NAMES[targetLanguage] || "English";
  const sourceLangName = LANGUAGE_NAMES[transcript.language || "en"] || "English";

  const completion = await openai.chat.completions.create({
    model: "gpt-4-turbo",
    messages: [
      {
        role: "system",
        content: `You are an expert multilingual lecture summarizer for educational institutions.
You receive lecture transcripts and produce comprehensive summaries in a DIFFERENT language from the source.
This is used by language schools and universities where students and teachers speak different languages.
ALL output MUST be in ${targetLangName}. Do NOT include any text in ${sourceLangName} except for proper nouns or technical terms that should remain in the original language.`,
      },
      {
        role: "user",
        content: `Analyze the following lecture transcript (originally in ${sourceLangName}) and create a comprehensive cross-language summary in ${targetLangName}.

Lecture title: ${transcript.title}
Lecture content:
${transcript.content}

Return JSON in this exact format:
{
  "summary": "Comprehensive summary in ${targetLangName} (300-500 characters)",
  "key_points": ["Key point 1", "Key point 2", "..."],
  "sections": [
    {"heading": "Section heading", "content": "Section content"}
  ],
  "source_language": "${sourceLangName}",
  "target_language": "${targetLangName}",
  "key_terms_bilingual": [
    {"original": "Term in source language", "translated": "Term in ${targetLangName}", "context": "Brief context"}
  ]
}

IMPORTANT: All text values (except 'original' in key_terms_bilingual) MUST be in ${targetLangName}.`,
      },
    ],
    response_format: { type: "json_object" },
    temperature: 0.3,
  });

  return JSON.parse(completion.choices[0].message.content || "{}");
}

// ========== カスタム用語集生成 ==========
async function handleGlossaryGenerate(
  openai: OpenAI,
  transcript: { content: string; title: string; language: string | null },
  targetLanguage: string,
  category?: string
) {
  const targetLangName = LANGUAGE_NAMES[targetLanguage] || "English";
  const categoryInstruction = category
    ? `Focus specifically on terms related to "${category}".`
    : "Extract all important academic and domain-specific terms.";

  const completion = await openai.chat.completions.create({
    model: "gpt-4-turbo",
    messages: [
      {
        role: "system",
        content: `You are a terminology extraction specialist for educational institutions.
You analyze lecture transcripts and extract key terms with clear, concise definitions.
These terms will be added to an organization's shared glossary for students and teachers.
Definitions should be in ${targetLangName}.`,
      },
      {
        role: "user",
        content: `Extract key terms from this lecture transcript and provide definitions in ${targetLangName}.

${categoryInstruction}

Lecture title: ${transcript.title}
Lecture content:
${transcript.content}

Return JSON in this exact format:
{
  "terms": [
    {
      "term": "The term (in its original language as used in the lecture)",
      "definition": "Clear, concise definition in ${targetLangName} (1-2 sentences)",
      "usage_example": "Example sentence from the lecture showing how the term is used",
      "difficulty": "beginner | intermediate | advanced"
    }
  ],
  "lecture_topic": "Brief topic description in ${targetLangName}",
  "total_terms_found": 0
}

Extract 10-25 of the most important terms. Prioritize terms that are:
1. Domain-specific or technical
2. Frequently used in the lecture
3. Essential for understanding the lecture content`,
      },
    ],
    response_format: { type: "json_object" },
    temperature: 0.2,
  });

  return JSON.parse(completion.choices[0].message.content || "{}");
}
