-- Add client_id (= iOS Lecture.id UUID) to transcripts so backfill from
-- local-only users is idempotent. Without this, the first sign-in of an
-- existing user with N local lectures would create N rows on every retry.
--
-- Strategy: nullable column + partial unique index. Old rows (created
-- before the iOS client started sending client_id) keep client_id = NULL
-- and are not deduped. Once the iOS client sends client_id, the unique
-- index per (user_id, client_id) prevents duplicates on retry.

ALTER TABLE transcripts
  ADD COLUMN IF NOT EXISTS client_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS transcripts_user_client_unique
  ON transcripts (user_id, client_id)
  WHERE client_id IS NOT NULL;
