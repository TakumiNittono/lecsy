-- mv3-uploads: anon ロールに storage.objects への INSERT 権限を付与
--
-- RLS policy があっても table-level GRANT がなければ INSERT は通らない。
-- Supabase 既定では anon に storage.objects の INSERT は付いていないため、
-- 明示的に GRANT する。
-- SELECT/UPDATE/DELETE は意図的に付けない (他人のアップロードを操作させないため)。

grant insert on storage.objects to anon;
