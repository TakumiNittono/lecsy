-- /k Hospital Live Interpreter — sessions & turns
-- 匿名 auth (signInAnonymously) で作られた auth.users と紐づく。
-- RLS で auth.uid() = user_id に限定。

create table if not exists public.k_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists k_sessions_user_id_created_idx
  on public.k_sessions (user_id, created_at desc);

create table if not exists public.k_turns (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.k_sessions(id) on delete cascade,
  kind text not null check (kind in ('said', 'question')),
  english text,
  japanese text,
  created_at timestamptz not null default now()
);
create index if not exists k_turns_session_created_idx
  on public.k_turns (session_id, created_at);

alter table public.k_sessions enable row level security;
alter table public.k_turns enable row level security;

-- k_sessions: 自分のセッションだけ
drop policy if exists "k_sessions_owner_select" on public.k_sessions;
create policy "k_sessions_owner_select" on public.k_sessions
  for select using (auth.uid() = user_id);

drop policy if exists "k_sessions_owner_insert" on public.k_sessions;
create policy "k_sessions_owner_insert" on public.k_sessions
  for insert with check (auth.uid() = user_id);

drop policy if exists "k_sessions_owner_update" on public.k_sessions;
create policy "k_sessions_owner_update" on public.k_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "k_sessions_owner_delete" on public.k_sessions;
create policy "k_sessions_owner_delete" on public.k_sessions
  for delete using (auth.uid() = user_id);

-- k_turns: 親セッションが自分のものなら可
drop policy if exists "k_turns_owner_select" on public.k_turns;
create policy "k_turns_owner_select" on public.k_turns
  for select using (
    exists (
      select 1 from public.k_sessions s
      where s.id = k_turns.session_id and s.user_id = auth.uid()
    )
  );

drop policy if exists "k_turns_owner_insert" on public.k_turns;
create policy "k_turns_owner_insert" on public.k_turns
  for insert with check (
    exists (
      select 1 from public.k_sessions s
      where s.id = k_turns.session_id and s.user_id = auth.uid()
    )
  );

drop policy if exists "k_turns_owner_delete" on public.k_turns;
create policy "k_turns_owner_delete" on public.k_turns
  for delete using (
    exists (
      select 1 from public.k_sessions s
      where s.id = k_turns.session_id and s.user_id = auth.uid()
    )
  );
