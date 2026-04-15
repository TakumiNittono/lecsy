-- pg_cron + pg_net 拡張を有効化し、Deepgram残高を6時間ごとにチェック
-- 参照: Deepgram/EXECUTION_PLAN.md W08、Deepgram/OPERATIONS.md
--
-- 注意: Supabaseはpg_cron / pg_netをDashboard >Database > Extensions
-- でも有効化可能。このmigrationが失敗する場合は手動で有効化してから再実行。

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- Vault に service_role_key が無い場合は手動で:
--   select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');
-- としてから cron を作る。

-- 既存ジョブがあれば作り直す
do $$
begin
  if exists (select 1 from cron.job where jobname = 'deepgram-balance-check-6h') then
    perform cron.unschedule('deepgram-balance-check-6h');
  end if;
end $$;

select cron.schedule(
  'deepgram-balance-check-6h',
  '0 */6 * * *',
  $$
    select net.http_post(
      url := 'https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/deepgram-balance-check',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization',
          'Bearer ' || coalesce(
            (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
            ''
          )
      )
    )
  $$
);

-- 古いalert削除（30日以上前）週次
do $$
begin
  if exists (select 1 from cron.job where jobname = 'cleanup-old-alerts') then
    perform cron.unschedule('cleanup-old-alerts');
  end if;
end $$;

select cron.schedule(
  'cleanup-old-alerts',
  '0 0 * * 0',
  $$ delete from public.system_alerts where created_at < now() - interval '30 days' $$
);
