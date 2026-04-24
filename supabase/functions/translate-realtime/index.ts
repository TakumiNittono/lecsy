// translate-realtime: Deepgramが確定した1文を GPT-4o Mini で翻訳して返す
// 参照: Deepgram/EXECUTION_PLAN.md W03
//
// 入力: { text: string, source_lang?: string, target_lang: string }
// 出力: { translated: string, target_lang: string }
//
// プランgate: Free は翻訳不可 (403 plan_upgrade_required)
// キャンペーン中 (~2026-06-01) は全員 pro 扱いで通過
//
// 要secret: OPENAI_API_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { alert, handleWithAlert } from '../_shared/alert.ts';

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
const CAMPAIGN_END_MS = new Date('2026-06-01T00:00:00+09:00').getTime();

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface TranslateRequest {
  text: string;
  source_lang?: string;  // 省略時は "auto"
  target_lang: string;   // "ja" | "en" | "zh" | "ko" | ...
}

const LANGUAGE_LABEL: Record<string, string> = {
  ja: 'Japanese',
  en: 'English',
  zh: 'Simplified Chinese',
  ko: 'Korean',
  vi: 'Vietnamese',
  es: 'Spanish',
  pt: 'Portuguese (Brazilian)',
};

Deno.serve(handleWithAlert('translate-realtime', async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (!OPENAI_API_KEY) return json({ error: 'server_misconfigured' }, 500);
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'unauthorized' }, 401);

  // ユーザー認証 + プラン判定
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: 'unauthorized' }, 401);

  const plan = await resolvePlan(supabase, user.id, user.email ?? '');
  if (plan === 'free') {
    return json({
      error: 'plan_upgrade_required',
      plan,
      feature: 'translation',
      message: 'Translation requires a Pro or Student plan. Free users see English captions only.',
    }, 403);
  }

  let body: TranslateRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const text = body.text?.trim();
  const target = body.target_lang;
  if (!text || !target) return json({ error: 'missing_fields' }, 400);

  const targetLabel = LANGUAGE_LABEL[target] ?? target;

  console.log(`[translate-realtime] user=${user.id} plan=${plan} target=${target} len=${text.length}`);

  const oaRes = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-5-nano',
      messages: [
        {
          role: 'system',
          content:
            `You are a real-time lecture interpreter for an international student. ` +
            `Translate the user's sentence to ${targetLabel}. ` +
            `Preserve academic terminology, speaker intent, and concise phrasing. ` +
            `Output ONLY the translated sentence. Do not add quotes or commentary.`,
        },
        { role: 'user', content: text },
      ],
    }),
  });

  if (!oaRes.ok) {
    const errText = await oaRes.text();
    console.error(`[translate-realtime] OpenAI error ${oaRes.status}: ${errText}`);
    await alert({
      source: 'translate-realtime',
      level: 'error',
      message: `OpenAI translation failed (status=${oaRes.status})`,
      context: { status: oaRes.status, user_id: user.id, target },
    });
    return json({ error: 'openai_failed', status: oaRes.status, detail: errText }, 502);
  }

  const data = await oaRes.json();
  const translated = (data.choices?.[0]?.message?.content ?? '').trim();
  if (!translated) {
    console.error(`[translate-realtime] empty translation, raw=${JSON.stringify(data).slice(0, 500)}`);
    return json({ error: 'empty_translation' }, 502);
  }

  return json({ translated, target_lang: target }, 200);
}));

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

async function resolvePlan(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  _email: string
): Promise<'free' | 'pro' | 'student'> {
  // 2026-06-08 ローンチ方針: B2B 専用。Stripe 個人経路は撤廃（iOS PlanService と同期）。
  const { data: orgMember } = await supabase
    .from('organization_members')
    .select('organizations!inner(plan)')
    .eq('user_id', userId)
    .eq('status', 'active')
    .limit(1)
    .maybeSingle();
  // deno-lint-ignore no-explicit-any
  if ((orgMember as any)?.organizations?.plan === 'pro') return 'pro';
  return 'free';
}
