-- mv3-uploads: 掃除 (streaming proxy 方式に切り替えたため Storage 経路は不要)
--
-- 流れとして:
--   1. /mp3 ページは当初 Storage round-trip で設計されていた
--   2. 50MB 超えに対応するため TUS resumable 方式を追加
--   3. 最終的に Edge Function streaming proxy 方式に切り替え → Storage 不要化
--
-- 本 migration は 20260423000000 〜 20260423040000 で追加した Storage 関連リソースを
-- 全て巻き戻す。

-- 1. Policies (storage.buckets)
drop policy if exists "Anon select mv3-uploads bucket" on storage.buckets;

-- 2. Policies (storage.objects)
drop policy if exists "Anon insert to mv3-uploads" on storage.objects;
drop policy if exists "Anon insert to mv3-uploads uploads/" on storage.objects;

-- 3. Policies (storage.s3_multipart_uploads)
drop policy if exists "Anon multipart mv3" on storage.s3_multipart_uploads;

-- 4. Policies (storage.s3_multipart_uploads_parts)
drop policy if exists "Anon multipart parts mv3" on storage.s3_multipart_uploads_parts;

-- 5. GRANTs の revoke (silent fail OK — postgres が owner でない場合は skip される)
do $$
begin
  begin
    revoke insert on storage.objects from anon;
  exception when insufficient_privilege then null;
  end;
  begin
    revoke select, insert, update, delete on storage.s3_multipart_uploads from anon;
  exception when insufficient_privilege then null;
  end;
  begin
    revoke select, insert, update, delete on storage.s3_multipart_uploads_parts from anon;
  exception when insufficient_privilege then null;
  end;
end $$;

-- 6. バケット本体の削除は Storage API 経由でしかできない (storage triggers が塞いでいる)。
--    このリポジトリのデプロイ手順では事前に以下を叩く想定:
--      curl -X DELETE "$SUPABASE_URL/storage/v1/bucket/mv3-uploads" \
--        -H "apikey: $SRV" -H "Authorization: Bearer $SRV"
