// Deepgram 短寿命トークン発行 Edge Function (plan-aware)
// 参照: Deepgram/EXECUTION_PLAN.md W01/W06、Deepgram/技術/Deepgram実装_単体版.md §4.4
//
// 安全弁:
//   L1: Deepgram残高 < $100 → 拒否
//   L2: ユーザー月次cap超過 → プランごとに異なる cap
//   L3: ユーザー日次 cap超過
//
// プラン別 cap (post-6/1、Rev.2):
//   free          : 英語ライブ字幕のみ、月 2h = 120min
//   student $7.99 : 英語+翻訳、月 10h = 600min
//   pro   $12.99  : 英語+翻訳、月 15h = 900min
//   power $24.99  : 英語+翻訳 (優先キュー)、月 30h = 1800min
//   org pro       : 月 15h/seat
//   キャンペーン中 (~2026-06-01): 全員 pro扱い
//
// 設計思想: Deepgram(STT)は全プランに開放。翻訳(GPT)だけStudent/Pro/Powerでgate。
// コアバリュー "講義中に助かる" を Free でも体験 → コンバージョン重視。
//
// デプロイ: supabase functions deploy deepgram-token
// 必要secrets: DEEPGRAM_ADMIN_KEY, DEEPGRAM_PROJECT_ID

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const DEEPGRAM_ADMIN_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY');
const DEEPGRAM_PROJECT_ID = Deno.env.get('DEEPGRAM_PROJECT_ID');

// キャンペーン終了日時 (JST)。_shared/campaign.ts と合わせる。
const CAMPAIGN_END_ISO = '2026-06-01T00:00:00+09:00';
const CAMPAIGN_END_MS = new Date(CAMPAIGN_END_ISO).getTime();

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface PlanCap {
  dailyMinutes: number;
  monthlyMinutes: number;
}

type Plan = 'free' | 'student' | 'pro' | 'power';

const PLAN_CAPS: Record<Plan, PlanCap> = {
  free:    { dailyMinutes: 30,  monthlyMinutes: 120 },  // 2h/月、英語のみ
  student: { dailyMinutes: 120, monthlyMinutes: 600 },  // 10h/月
  pro:     { dailyMinutes: 180, monthlyMinutes: 900 },  // 15h/月
  power:   { dailyMinutes: 240, monthlyMinutes: 1800 }, // 30h/月
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (!DEEPGRAM_ADMIN_KEY || !DEEPGRAM_PROJECT_ID) {
    return json({ error: 'server_misconfigured' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'unauthorized' }, 401);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: 'unauthorized' }, 401);

  // Feature flag
  const { data: flag } = await supabase
    .from('feature_flags')
    .select('enabled')
    .eq('name', 'realtime_captions_beta')
    .maybeSingle();
  if (!flag?.enabled) return json({ error: 'feature_disabled' }, 503);

  // プラン判定 (2026-06-08 ローンチ方針):
  // B2B 専用。active な organization_members で org.plan='pro' の時だけ pro。
  // 個人 Stripe 経路は撤廃（iOS 側ポリシーと同期）。
  let plan: Plan = 'free';

  const { data: orgMembership } = await supabase
    .from('organization_members')
    .select('organizations!inner(plan)')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .limit(1)
    .maybeSingle();
  // @ts-expect-error supabase-js nested typing
  if (orgMembership?.organizations?.plan === 'pro') plan = 'pro';

  const cap = PLAN_CAPS[plan];

  // L1: Deepgram残高
  const balRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/balances`,
    { headers: { Authorization: `Token ${DEEPGRAM_ADMIN_KEY}` } }
  );
  if (!balRes.ok) return json({ error: 'balance_check_failed' }, 502);
  const balJson = await balRes.json();
  const balance = Number(balJson.balances?.[0]?.amount ?? 0);
  if (balance < 100) return json({ error: 'budget_exceeded', balance }, 402);

  // L3: 日次cap
  const today = new Date().toISOString().split('T')[0];
  const { data: dailyRow } = await supabase
    .from('user_daily_realtime_usage')
    .select('minutes_today')
    .eq('user_id', user.id)
    .eq('usage_date', today)
    .maybeSingle();
  const dailyUsed = dailyRow?.minutes_today ?? 0;
  if (dailyUsed >= cap.dailyMinutes) {
    return json({
      error: 'daily_cap', plan, cap: cap.dailyMinutes, used: dailyUsed,
    }, 429);
  }

  // L2: 月次cap
  const monthStart = today.slice(0, 7) + '-01';
  const { data: monthRow } = await supabase
    .from('user_monthly_realtime_usage')
    .select('minutes_month')
    .eq('user_id', user.id)
    .eq('usage_month', monthStart)
    .maybeSingle();
  const monthlyUsed = monthRow?.minutes_month ?? 0;
  if (monthlyUsed >= cap.monthlyMinutes) {
    return json({
      error: 'monthly_cap', plan, cap: cap.monthlyMinutes, used: monthlyUsed,
    }, 429);
  }

  // 短寿命トークン発行 (TTL 15分)
  const tokenRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/keys`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${DEEPGRAM_ADMIN_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        comment: `user:${user.id} plan:${plan}`,
        scopes: ['usage:write'],
        time_to_live_in_seconds: 900,
      }),
    }
  );

  if (!tokenRes.ok) {
    return json({ error: 'token_mint_failed', status: tokenRes.status }, 500);
  }

  const { key } = await tokenRes.json();
  return json({
    token: key,
    ttl_seconds: 900,
    plan,
    cap_monthly_minutes: cap.monthlyMinutes,
    monthly_used: monthlyUsed,
  }, 200);
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
