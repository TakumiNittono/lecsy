-- 2026-04-22 one-shot cleanup: cross-user backfill leak の後始末
--
-- 背景: 2026-04-22 の実機ログで以下が観測された
--   1. User A (BE97538B, Pro / org=298ed90b-...) がローカル 51 lecture を保持
--   2. User A サインアウト
--   3. User B (54B532EB, maeyamajinkouenkai@gmail.com, Free, no org) サインイン
--   4. AuthService の自動 backfill が発火、User A のローカル lecture 51件全てを
--      User B のアカウントに organization_id=NULL で upload してしまった
--   5. `Cloud backfill: 51/51` の行で完了
--
-- アプリ側は commit 1aa16a4 で自動 backfill を廃止し再発防止済。
-- このマイグレーションは既に Supabase に流れてしまった orphan 行を削除する。
--
-- 削除スコープ: user_id = 54B532EB かつ organization_id IS NULL。
-- このユーザは backfill を受け取った瞬間が Supabase 初接触だったので、
-- org_id=NULL の行は全て backfill 由来のゴミ (legitimate な個人録音は存在しない)。

DO $$
DECLARE
  orphan_count INT;
  deleted_count INT;
BEGIN
  SELECT COUNT(*) INTO orphan_count
  FROM public.transcripts
  WHERE user_id = '54B532EB-5043-4C0A-8C16-21961826CDA6'
    AND organization_id IS NULL;

  RAISE NOTICE 'cleanup_cross_user_backfill: found % orphan rows', orphan_count;

  -- 安全ガード: ログに基づく想定は 51 件。大きく逸脱していたら abort。
  IF orphan_count > 100 THEN
    RAISE EXCEPTION 'cleanup_cross_user_backfill: safety check failed — expected ≤100 rows, got %', orphan_count;
  END IF;

  DELETE FROM public.transcripts
  WHERE user_id = '54B532EB-5043-4C0A-8C16-21961826CDA6'
    AND organization_id IS NULL;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'cleanup_cross_user_backfill: deleted % rows', deleted_count;
END $$;
