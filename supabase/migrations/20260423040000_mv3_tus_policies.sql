-- mv3-uploads TUS レジューマブル対応 — 必要な policy を網羅的に追加
--
-- Supabase Storage の TUS 実装は以下のテーブルを使う:
--   - storage.buckets            (bucket メタ参照)
--   - storage.s3_multipart_uploads      (multipart upload の状態管理)
--   - storage.s3_multipart_uploads_parts (各チャンクの記録)
--   - storage.objects            (完了時に移行)
-- anon ロールがこれら全てにアクセスできないと 403 (RLS violation) で落ちる。
--
-- 本ポリシーは bucket_id = 'mv3-uploads' に限定し、他 bucket への巻き込みを防ぐ。
-- PIN ゲートは mv3-transcribe (文字起こし実行) 側で確実に行うため、
-- upload 経路を anon に開いてもコスト発生しない設計。

-- 1. storage.buckets — mv3-uploads のメタ参照を anon に許可
drop policy if exists "Anon select mv3-uploads bucket" on storage.buckets;
create policy "Anon select mv3-uploads bucket"
  on storage.buckets
  for select
  to anon
  using (id = 'mv3-uploads');

-- 2. storage.s3_multipart_uploads — TUS multipart 本体
grant select, insert, update, delete on storage.s3_multipart_uploads to anon;

drop policy if exists "Anon multipart mv3" on storage.s3_multipart_uploads;
create policy "Anon multipart mv3"
  on storage.s3_multipart_uploads
  for all
  to anon
  using (bucket_id = 'mv3-uploads')
  with check (bucket_id = 'mv3-uploads');

-- 3. storage.s3_multipart_uploads_parts — 各チャンク
grant select, insert, update, delete on storage.s3_multipart_uploads_parts to anon;

drop policy if exists "Anon multipart parts mv3" on storage.s3_multipart_uploads_parts;
create policy "Anon multipart parts mv3"
  on storage.s3_multipart_uploads_parts
  for all
  to anon
  using (bucket_id = 'mv3-uploads')
  with check (bucket_id = 'mv3-uploads');
