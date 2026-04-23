-- mv3-uploads: 匿名 INSERT ポリシーを bucket 一致まで緩める
--
-- 前の policy (name like 'uploads/%' 付き) は TUS レジューマブルの内部挙動と
-- かみ合わず 403 になる。TUS は storage.objects への INSERT 時に独自の
-- placeholder name を使う場合があるため、name 条件を外して bucket 一致のみにする。
-- path の妥当性は mv3-transcribe 側で starts_with('uploads/') を必ず確認している。

drop policy if exists "Anon insert to mv3-uploads uploads/" on storage.objects;
drop policy if exists "Anon insert to mv3-uploads" on storage.objects;

create policy "Anon insert to mv3-uploads"
  on storage.objects
  for insert
  to anon
  with check (bucket_id = 'mv3-uploads');

-- TUS は成功時に storage.objects 上の row を UPDATE (metadata 確定)、失敗時に DELETE する。
-- anon に UPDATE / DELETE を許すと他人のアップロードを潰せるため、ここでは許可しない。
-- (※ TUS の UPDATE/DELETE は service role 経由で Supabase 内部が実施する想定)
