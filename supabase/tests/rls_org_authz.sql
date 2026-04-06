-- pgTAP RLS authorization tests for the v4 B2B model.
--
-- Run with one of:
--   supabase test db
--   psql "$DATABASE_URL" -f supabase/tests/rls_org_authz.sql
--
-- Requires the pgtap extension. The test wraps everything in a transaction
-- and rolls back at the end so it can be re-run safely.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(11);

-- ---- Fixture: two organizations, four users ----
-- We bypass auth.users by inserting the minimum needed columns.
INSERT INTO auth.users (id, email)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'owner-a@a.test'),
  ('00000000-0000-0000-0000-000000000002', 'admin-a@a.test'),
  ('00000000-0000-0000-0000-000000000003', 'teacher-a@a.test'),
  ('00000000-0000-0000-0000-000000000004', 'student-a@a.test'),
  ('00000000-0000-0000-0000-000000000005', 'owner-b@b.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO organizations (id, name, slug, type, plan, max_seats, allowed_email_domains)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Org A', 'org-a', 'language_school', 'starter', 3, ARRAY['a.test']),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Org B', 'org-b', 'language_school', 'starter', 5, NULL);

INSERT INTO organization_members (org_id, user_id, email, role, status) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000001', 'owner-a@a.test',   'owner',   'active'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000002', 'admin-a@a.test',   'admin',   'active'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000003', 'teacher-a@a.test', 'teacher', 'active'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000004', 'student-a@a.test', 'student', 'active'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000005', 'owner-b@b.test',   'owner',   'active');

-- A class in Org A, with student-a as the only enrolled student.
INSERT INTO org_classes (id, org_id, name, language, teacher_id, created_by)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'English 101', 'en',
        '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003');
INSERT INTO org_class_members (class_id, user_id)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', '00000000-0000-0000-0000-000000000004');

-- ---- Helper to set the current JWT user ----
CREATE OR REPLACE FUNCTION _as_user(uid UUID) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid::text)::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$;

-- =====================================================================
-- 1. Owner can SELECT their own org
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000001');
SELECT ok(
  EXISTS(SELECT 1 FROM organizations WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'owner can SELECT their own org'
);

-- =====================================================================
-- 2. Owner can UPDATE org name
-- =====================================================================
SELECT lives_ok(
  $$ UPDATE organizations SET name = 'Org A v2'
     WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  'owner can UPDATE their org'
);

-- =====================================================================
-- 3. Admin can INSERT a new member
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000002');
SELECT lives_ok(
  $$ INSERT INTO organization_members (org_id, email, role, status)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'new1@a.test', 'student', 'pending') $$,
  'admin can INSERT pending members'
);

-- =====================================================================
-- 4. Teacher can SELECT members but not INSERT
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000003');
SELECT ok(
  (SELECT count(*) FROM organization_members
   WHERE org_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') >= 4,
  'teacher can SELECT org members'
);
SELECT throws_ok(
  $$ INSERT INTO organization_members (org_id, email, role, status)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'sneaky@a.test', 'student', 'pending') $$,
  NULL,
  'teacher cannot INSERT members'
);

-- =====================================================================
-- 5. Cross-org isolation: owner B cannot see Org A
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000005');
SELECT ok(
  NOT EXISTS(SELECT 1 FROM organizations WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'cross-org isolation: owner B cannot SELECT Org A'
);

-- =====================================================================
-- 6. Last-owner protection: cannot demote the only owner
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ UPDATE organization_members SET role = 'admin'
     WHERE org_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND user_id = '00000000-0000-0000-0000-000000000001' $$,
  NULL,
  'cannot demote the last owner'
);

-- =====================================================================
-- 7. Seat-limit enforcement (max_seats = 3, already 4+ members → next insert fails)
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000002');
SELECT throws_ok(
  $$ INSERT INTO organization_members (org_id, email, role, status)
     VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'over@a.test', 'student', 'pending') $$,
  'seat_limit_exceeded',
  'seat-limit trigger blocks inserts past the cap'
);

-- =====================================================================
-- 8. Domain restriction: csv_import-style insert with wrong domain.
--    Note: the DB-level check lives in the Edge Function, so here we just
--    assert that allowed_email_domains is set on the org and would be
--    enforced. (If a domain trigger ships later, swap this to throws_ok.)
-- =====================================================================
SELECT ok(
  (SELECT 'a.test' = ANY(allowed_email_domains)
   FROM organizations WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'org has domain restriction configured'
);

-- =====================================================================
-- 9. Visibility=private transcript hidden from other org members
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000001');
INSERT INTO transcripts (id, user_id, title, content, organization_id, visibility, created_at)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Owner Private Note',
        'secret', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'private', now());

SELECT _as_user('00000000-0000-0000-0000-000000000003');
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM transcripts
    WHERE title = 'Owner Private Note'
  ),
  'visibility=private hidden from other org members'
);

-- =====================================================================
-- 10. Visibility=org_wide visible to all active members
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000001');
INSERT INTO transcripts (id, user_id, title, content, organization_id, visibility, created_at)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Org Wide Memo',
        'hi', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'org_wide', now());

SELECT _as_user('00000000-0000-0000-0000-000000000004');
SELECT ok(
  EXISTS(SELECT 1 FROM transcripts WHERE title = 'Org Wide Memo'),
  'visibility=org_wide visible to other active members'
);

-- =====================================================================
-- 11. Student in a class can see class-visibility transcripts
-- =====================================================================
SELECT _as_user('00000000-0000-0000-0000-000000000003');
INSERT INTO transcripts (id, user_id, title, content, organization_id, class_id, visibility, created_at)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000003', 'Class Lecture',
        'lesson', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', 'class', now());

SELECT _as_user('00000000-0000-0000-0000-000000000004');
SELECT ok(
  EXISTS(SELECT 1 FROM transcripts WHERE title = 'Class Lecture'),
  'enrolled student can SELECT class-visibility transcripts'
);

SELECT * FROM finish();

ROLLBACK;
