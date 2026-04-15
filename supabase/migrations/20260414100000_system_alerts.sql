-- system_alerts: 運用アラートを記録するテーブル
-- 参照: Deepgram/EXECUTION_PLAN.md W08
--
-- deepgram-balance-check や将来のmonitoring functionから書き込み。
-- ダッシュボードで select * from system_alerts where created_at > now() - interval '24 hours' する。

create table if not exists public.system_alerts (
  id          uuid primary key default gen_random_uuid(),
  source      text not null,                         -- 'deepgram-balance-check' 等
  level       text not null check (level in ('info', 'warning', 'critical')),
  message     text not null,
  payload     jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists idx_system_alerts_created_at
  on public.system_alerts (created_at desc);

create index if not exists idx_system_alerts_level
  on public.system_alerts (level, created_at desc);

alter table public.system_alerts enable row level security;

-- super admin（メール固定）だけ閲覧可能。既存パターンに合わせる。
create policy "super_admins read alerts"
  on public.system_alerts for select
  using (
    exists (
      select 1 from auth.users
      where auth.users.id = (select auth.uid())
        and auth.users.email = 'nittonotakumi@gmail.com'
    )
  );

create policy "service writes alerts"
  on public.system_alerts for all
  using (auth.jwt() ->> 'role' = 'service_role')
  with check (auth.jwt() ->> 'role' = 'service_role');
