// deepgram-balance-check: 残高監視 + 低残高時の自動機能停止
// 参照: Deepgram/EXECUTION_PLAN.md W08
//
// 動作:
//   - Deepgram残高をfetch
//   - balance < $50 → realtime_captions_beta フラグを自動 OFF + system_alerts 記録
//   - balance < $150 → 警告レベルでalert記録（フラグはON維持）
//   - 結果をJSONで返す（cronとモニタリングダッシュボード両用）
//
// cron登録（Supabase Dashboard > Database > Cron で1日1回実行）:
//   select cron.schedule(
//     'deepgram-balance-check',
//     '0 */6 * * *',  -- 6時間ごと
//     $$ select net.http_post(
//       url := 'https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/deepgram-balance-check',
//       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
//     ) $$
//   );

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
    return json({ error: 'server_misconfigured' }, 500);
  }

  // 残高取得
  const balRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/balances`,
    { headers: { Authorization: `Token ${DEEPGRAM_ADMIN_KEY}` } }
  );
  if (!balRes.ok) {
    return json({ error: 'balance_fetch_failed', status: balRes.status }, 502);
  }
  const balJson = await balRes.json();
  const balance = Number(balJson.balances?.[0]?.amount ?? 0);

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
    const msg = 'Feature realtime_captions_beta auto-disabled';
    await recordAlert(supabase, 'critical', balance, msg);
    await postSlack('critical', balance, msg);
  } else if (balance < WARNING_THRESHOLD) {
    level = 'warning';
    const msg = `Balance below warning threshold ($${WARNING_THRESHOLD})`;
    await recordAlert(supabase, 'warning', balance, msg);
    await postSlack('warning', balance, msg);
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

async function recordAlert(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  level: 'warning' | 'critical',
  balance: number,
  message: string
) {
  try {
    await supabase.from('system_alerts').insert({
      source: 'deepgram-balance-check',
      level,
      message,
      payload: { balance },
    });
  } catch (e) {
    console.error('[deepgram-balance-check] alert insert failed', e);
  }
}

// SLACK_WEBHOOK_URL が設定されていれば警告/critical時にSlackへ通知する。
// 未設定なら何もしない（ローカル開発・小規模運用でも落ちない）。
async function postSlack(
  level: 'warning' | 'critical',
  balance: number,
  message: string
) {
  const url = Deno.env.get('SLACK_WEBHOOK_URL');
  if (!url) return;
  const emoji = level === 'critical' ? ':rotating_light:' : ':warning:';
  const text = `${emoji} *Deepgram balance ${level}*\n` +
    `Balance: $${balance.toFixed(2)}\n` +
    `${message}`;
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
    });
  } catch (e) {
    console.error('[deepgram-balance-check] slack post failed', e);
  }
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
