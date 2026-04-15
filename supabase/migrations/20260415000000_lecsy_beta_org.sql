-- Lecsy Beta Testers 組織をシードする
-- 参照: Deepgram/memo.md フェーズ1-2
--
-- 俺が追加した人だけ Pro 機能を使えるようにする仕組み。
-- Web `/org/lecsy-beta/members` から super admin (nittonotakumi@gmail.com) が
-- メンバーを追加/削除する。members は `organization_members.status='active'` で
-- かつ org.plan='pro' なので、iOS `PlanService` / Edge Functions `deepgram-token` が
-- 自動的に Pro 扱いする。

do $$
declare
  beta_id uuid;
  owner_id uuid;
begin
  -- nittonotakumi@gmail.com の user_id を取得
  select id into owner_id from auth.users where email = 'nittonotakumi@gmail.com' limit 1;

  -- 既存チェック
  select id into beta_id from public.organizations where slug = 'lecsy-beta';

  if beta_id is null then
    insert into public.organizations (name, slug, plan, created_at)
    values ('Lecsy Beta Testers', 'lecsy-beta', 'pro', now())
    returning id into beta_id;
    raise notice 'Created lecsy-beta org: %', beta_id;
  else
    update public.organizations set plan = 'pro' where id = beta_id;
    raise notice 'lecsy-beta org already exists: %', beta_id;
  end if;

  -- owner として super admin を追加（存在しない場合のみ）
  if owner_id is not null then
    insert into public.organization_members (org_id, user_id, role, status, joined_at)
    values (beta_id, owner_id, 'owner', 'active', now())
    on conflict (org_id, user_id) do update set role = 'owner', status = 'active';
    raise notice 'Added super admin as owner of lecsy-beta';
  else
    raise notice 'super admin user not found yet — add manually later';
  end if;
end $$;
