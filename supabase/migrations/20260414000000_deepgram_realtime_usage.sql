-- Deepgram Nova-3 Streaming 用の使用量追跡とFeature Flag
-- 参照: Deepgram/EXECUTION_PLAN.md W01、Deepgram/技術/Deepgram実装_単体版.md §4

-- =====================================================
-- 1. 日次リアルタイム使用量（安全弁L3）
-- =====================================================
create table if not exists public.user_daily_realtime_usage (
  user_id       uuid references auth.users(id) on delete cascade,
  usage_date    date not null default current_date,
  minutes_today numeric(10,2) not null default 0,
  updated_at    timestamptz not null default now(),
  primary key (user_id, usage_date)
);

alter table public.user_daily_realtime_usage enable row level security;

create policy "users read own daily usage"
  on public.user_daily_realtime_usage
  for select using (auth.uid() = user_id);

create policy "service writes daily usage"
  on public.user_daily_realtime_usage
  for all using (auth.jwt() ->> 'role' = 'service_role')
  with check (auth.jwt() ->> 'role' = 'service_role');

create index if not exists idx_daily_usage_date
  on public.user_daily_realtime_usage (usage_date);

-- =====================================================
-- 2. 月次使用量（安全弁L2）
-- =====================================================
create table if not exists public.user_monthly_realtime_usage (
  user_id        uuid references auth.users(id) on delete cascade,
  usage_month    date not null,  -- 月初日で正規化 (YYYY-MM-01)
  minutes_month  numeric(10,2) not null default 0,
  updated_at     timestamptz not null default now(),
  primary key (user_id, usage_month)
);

alter table public.user_monthly_realtime_usage enable row level security;

create policy "users read own monthly usage"
  on public.user_monthly_realtime_usage
  for select using (auth.uid() = user_id);

create policy "service writes monthly usage"
  on public.user_monthly_realtime_usage
  for all using (auth.jwt() ->> 'role' = 'service_role')
  with check (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- 3. Feature Flag（Deepgram残高低下時の自動停止用）
-- =====================================================
create table if not exists public.feature_flags (
  name       text primary key,
  enabled    boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags (name, enabled)
values ('realtime_captions_beta', true)
on conflict (name) do nothing;

alter table public.feature_flags enable row level security;

create policy "everyone reads feature flags"
  on public.feature_flags for select using (true);

create policy "service writes feature flags"
  on public.feature_flags for all
  using (auth.jwt() ->> 'role' = 'service_role')
  with check (auth.jwt() ->> 'role' = 'service_role');
