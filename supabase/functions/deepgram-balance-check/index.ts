// deepgram-balance-check: 残高監視 + 低残高時の自動機能停止
// 参照: Deepgram/EXECUTION_PLAN.md W08
//
// 動作:
//   - Deepgram残高をfetch
//   - balance < $50 → realtime_captions_beta フラグを自動 OFF + critical alert
//   - balance < $150 → warning alert (フラグはON維持)
//   - 結果をJSONで返す (cronとモニタリングダッシュボード両用)
//   - アラート送出は `_shared/alert.ts` 経由で Slack + Sentry + system_alerts に同時送出
//
// cron登録 (Supabase Dashboard > Database > Cron で6時間毎):
//   select cron.schedule(
//     'deepgram-balance-check',
//     '0 */6 * * *',
//     $$ select net.http_post(
//       url := 'https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/deepgram-balance-check',
//       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
//     ) $$
//   );

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { alert } from '../_shared/alert.ts';

const DEEPGRAM_ADMIN_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY');
const DEEPGRAM_PROJECT_ID = Deno.env.get('DEEPGRAM_PROJECT_ID');

const CRITICAL_THRESHOLD = 50;
const WARNING_THRESHOLD = 150;

interface BalanceCheckResult {
  balance: number;
  level: 'ok' | 'warning' | 'critical';
  feature_disabled: boolean;
  checked_at: string;
}

serve(async () => {
  if (!DEEPGRAM_ADMIN_KEY || !DEEPGRAM_PROJECT_ID) {
    await alert({
      source: 'deepgram-balance-check',
      level: 'error',
      message: 'server_misconfigured: DEEPGRAM_ADMIN_KEY or DEEPGRAM_PROJECT_ID not set',
    });
    return json({ error: 'server_misconfigured' }, 500);
  }

  // 残高取得
  const balRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/balances`,
    { headers: { Authorization: `Token ${DEEPGRAM_ADMIN_KEY}` } }
  );
  if (!balRes.ok) {
    await alert({
      source: 'deepgram-balance-check',
      level: 'error',
      message: `balance_fetch_failed (status=${balRes.status})`,
      context: { status: balRes.status },
    });
    return json({ error: 'balance_fetch_failed', status: balRes.status }, 502);
  }
  const balJson = await balRes.json();
  const balance = Number(balJson.balances?.[0]?.amount ?? 0);

  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
  // deno-lint-ignore no-explicit-any
  const supabase = createClient<any, any, any>(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  let level: BalanceCheckResult['level'] = 'ok';
  let featureDisabled = false;

  if (balance < CRITICAL_THRESHOLD) {
    level = 'critical';
    featureDisabled = true;
    // 自動停止
    await supabase
      .from('feature_flags')
      .update({ enabled: false, updated_at: new Date().toISOString() })
      .eq('name', 'realtime_captions_beta');
    await alert({
      source: 'deepgram-balance-check',
      level: 'critical',
      message: `Deepgram balance CRITICAL — realtime_captions_beta auto-disabled. Recharge immediately.`,
      context: {
        balance_usd: balance,
        threshold_usd: CRITICAL_THRESHOLD,
        feature_disabled: 'realtime_captions_beta',
      },
    });
  } else if (balance < WARNING_THRESHOLD) {
    level = 'warning';
    await alert({
      source: 'deepgram-balance-check',
      level: 'warning',
      message: `Deepgram balance below warning threshold.`,
      context: {
        balance_usd: balance,
        threshold_usd: WARNING_THRESHOLD,
      },
    });
  }

  const result: BalanceCheckResult = {
    balance,
    level,
    feature_disabled: featureDisabled,
    checked_at: new Date().toISOString(),
  };

  console.log(`[deepgram-balance-check] balance=$${balance} level=${level}`);
  return json(result, 200);
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
