-- B2B 営業リード保存 + UF ELI / Santa Fe College ESL の事前シード
--
-- 2026-06-08 ローンチに向けた営業前提:
--   - UF ELI と Santa Fe の 2 校に絞る (Deepgram/EXECUTION_PLAN.md MVP 凍結スコープ)
--   - 両校とも 2026-06-01 まで完全無料パイロット
--   - ファウンダー (nittonotakumi@gmail.com) を両 org の owner としてシード
--     → 打合せ中に `/org/[slug]/members` で学校 admin を招待する運用
--
-- pilot_leads: /schools/demo フォームからの問い合わせ受け皿
--   - service_role のみ書き込み可 (anon API が admin client 経由で INSERT)
--   - アプリ層で isSuperAdmin() gate をかけて読む (RLS ポリシーは空 = 非 service_role は全拒否)

-- ============================================
-- 1. pilot_leads テーブル
-- ============================================

do $$ begin
  create type pilot_lead_status as enum (
    'new',
    'contacted',
    'demo_scheduled',
    'in_pilot',
    'closed_won',
    'closed_lost'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.pilot_leads (
  id uuid primary key default gen_random_uuid(),
  school_name text not null,
  contact_name text not null,
  contact_email text not null,
  role text,
  phone text,
  notes text,
  source text not null default 'schools_demo_form',
  status pilot_lead_status not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pilot_leads_status_created_idx
  on public.pilot_leads (status, created_at desc);

create index if not exists pilot_leads_email_idx
  on public.pilot_leads (lower(contact_email));

alter table public.pilot_leads enable row level security;
-- 意図的にポリシー無し: 非 service_role からは完全に不可視。
-- Web 側で super_admin 閲覧 UI が必要になったら別マイグレーションで policy 追加。

-- updated_at 自動更新
create or replace function public.pilot_leads_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists pilot_leads_touch_updated_at on public.pilot_leads;
create trigger pilot_leads_touch_updated_at
  before update on public.pilot_leads
  for each row execute function public.pilot_leads_touch_updated_at();

-- ============================================
-- 2. UF ELI org シード
-- ============================================
do $$
declare
  uf_id uuid;
  sf_id uuid;
  founder_id uuid;
begin
  select id into founder_id
  from auth.users
  where email = 'nittonotakumi@gmail.com'
  limit 1;

  -- ---- UF ELI ----
  select id into uf_id from public.organizations where slug = 'uf-eli';
  if uf_id is null then
    insert into public.organizations (
      name, slug, type, plan, max_seats,
      allowed_email_domains, trial_ends_at, settings
    )
    values (
      'University of Florida — English Language Institute',
      'uf-eli',
      'university_iep',
      'free',
      250,
      array['ufl.edu', 'eli.ufl.edu'],
      '2026-06-01T23:59:59Z',
      jsonb_build_object(
        'display_name', 'UF ELI',
        'institution_full', 'University of Florida',
        'retention_days', 90,
        'pilot_through', '2026-06-01'
      )
    )
    returning id into uf_id;
    raise notice 'Created UF ELI org: %', uf_id;
  else
    update public.organizations
    set type = 'university_iep',
        plan = 'free',
        max_seats = 250,
        allowed_email_domains = array['ufl.edu', 'eli.ufl.edu'],
        trial_ends_at = '2026-06-01T23:59:59Z',
        settings = coalesce(settings, '{}'::jsonb) || jsonb_build_object(
          'display_name', 'UF ELI',
          'institution_full', 'University of Florida',
          'retention_days', 90,
          'pilot_through', '2026-06-01'
        )
    where id = uf_id;
    raise notice 'UF ELI org already exists, updated: %', uf_id;
  end if;

  if founder_id is not null then
    insert into public.organization_members (org_id, user_id, role, status, joined_at)
    values (uf_id, founder_id, 'owner', 'active', now())
    on conflict (org_id, user_id) do update set role = 'owner', status = 'active';
  end if;

  -- ---- Santa Fe College ESL ----
  select id into sf_id from public.organizations where slug = 'santa-fe-esl';
  if sf_id is null then
    insert into public.organizations (
      name, slug, type, plan, max_seats,
      allowed_email_domains, trial_ends_at, settings
    )
    values (
      'Santa Fe College — ESL Program',
      'santa-fe-esl',
      'college',
      'free',
      100,
      array['sfcollege.edu'],
      '2026-06-01T23:59:59Z',
      jsonb_build_object(
        'display_name', 'Santa Fe ESL',
        'institution_full', 'Santa Fe College',
        'retention_days', 90,
        'pilot_through', '2026-06-01'
      )
    )
    returning id into sf_id;
    raise notice 'Created Santa Fe ESL org: %', sf_id;
  else
    update public.organizations
    set type = 'college',
        plan = 'free',
        max_seats = 100,
        allowed_email_domains = array['sfcollege.edu'],
        trial_ends_at = '2026-06-01T23:59:59Z',
        settings = coalesce(settings, '{}'::jsonb) || jsonb_build_object(
          'display_name', 'Santa Fe ESL',
          'institution_full', 'Santa Fe College',
          'retention_days', 90,
          'pilot_through', '2026-06-01'
        )
    where id = sf_id;
    raise notice 'Santa Fe ESL org already exists, updated: %', sf_id;
  end if;

  if founder_id is not null then
    insert into public.organization_members (org_id, user_id, role, status, joined_at)
    values (sf_id, founder_id, 'owner', 'active', now())
    on conflict (org_id, user_id) do update set role = 'owner', status = 'active';
  else
    raise notice 'founder user not yet in auth.users — re-run this migration after first sign-in';
  end if;
end $$;
