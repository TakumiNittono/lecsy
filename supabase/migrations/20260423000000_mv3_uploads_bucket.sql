-- mv3-uploads storage bucket
--
-- /mp3 ページ (母用の個人文字起こしページ) が長尺 MP3 を一時置きする private バケット。
-- 署名付きアップロード URL 経由でブラウザから直接 PUT → mv3-transcribe が
-- 署名付きダウンロード URL を生成して Deepgram に渡し、完了後に削除する。
--
-- 2 時間講義 (128kbps MP3 ≒ 115MB) を通すため file_size_limit を 500MB に設定。

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mv3-uploads',
  'mv3-uploads',
  false,
  524288000,  -- 500 MB
  array[
    'audio/mpeg',
    'audio/mp3',
    'audio/mp4',
    'audio/m4a',
    'audio/x-m4a',
    'audio/wav',
    'audio/x-wav',
    'audio/wave'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- public / authenticated からの直接アクセスは一切許可しない。
-- mv3-sign-upload / mv3-transcribe が service_role で署名付き URL を発行する経路のみ。
-- service_role は RLS をバイパスするので明示ポリシー不要。
