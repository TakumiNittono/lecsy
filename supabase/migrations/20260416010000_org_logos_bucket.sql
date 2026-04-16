-- org-logos storage bucket
--
-- /org/[slug]/settings で学校 admin がアップロードした org ロゴを保存する。
-- - public read: ログインヘッダーで `<img src={logo_url}>` として直接参照
-- - service-role write only: アップロードは /api/org/[slug]/logo 経由で
--   requireOrgRole('admin') を通過した場合のみ許可

insert into storage.buckets (id, name, public)
values ('org-logos', 'org-logos', true)
on conflict (id) do update set public = excluded.public;

-- Public read (匿名でもロゴ URL を描画できる)
drop policy if exists "Public read on org-logos" on storage.objects;
create policy "Public read on org-logos"
  on storage.objects
  for select
  to public
  using (bucket_id = 'org-logos');

-- Write/Update/Delete は service_role のみ (アプリ層で admin 認可済み呼び出し)
-- ※ authenticated ユーザー直書きは防ぎたいのでポリシーを作らない。
--   service_role は RLS をバイパスするので明示ポリシー不要。
