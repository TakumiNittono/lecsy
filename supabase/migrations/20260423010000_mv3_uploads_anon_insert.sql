-- mv3-uploads: 匿名 INSERT 許可ポリシー
--
-- Supabase Storage の標準 PUT は platform 上限 50MB。
-- 2 時間級 MP3 (〜115MB) を通すには TUS レジューマブル (/storage/v1/upload/resumable)
-- を使うしかなく、この endpoint は Bearer JWT を要求する。
-- /mp3 ページは PIN ゲート済み (mv3-transcribe 側で検証) なので、
-- 匿名ロールからの INSERT を mv3-uploads/uploads/* 限定で許可する。
--
-- リスク抑制:
--   - INSERT のみ許可 (SELECT/UPDATE/DELETE 無し)
--   - path prefix を uploads/ に固定 (client 生成の UUID を前提)
--   - mv3-transcribe が処理成否に関わらず object を削除する → orphan が溜まらない
--   - bucket の file_size_limit = 500MB で上限を担保

drop policy if exists "Anon insert to mv3-uploads uploads/" on storage.objects;
create policy "Anon insert to mv3-uploads uploads/"
  on storage.objects
  for insert
  to anon
  with check (
    bucket_id = 'mv3-uploads'
    and name like 'uploads/%'
  );
