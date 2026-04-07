-- Fix: organization_members audit trigger fails on cascade-delete from organizations
-- Symptom: deleting an org with members → trigger fires AFTER DELETE on members
-- → tries to INSERT into audit_logs(org_id=...) → FK violation because the org row
-- has already been removed by the cascade.
--
-- Fix: in the DELETE branch, only insert audit row if the parent org still exists.
-- The org deletion itself is audited elsewhere (or by future org-delete edge function),
-- so we don't lose information.

CREATE OR REPLACE FUNCTION audit_organization_members()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor    UUID;
  v_email    TEXT;
  v_action   TEXT;
  v_target   TEXT;
  v_meta     JSONB;
  v_org_id   UUID;
  v_org_exists BOOLEAN;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NOT NULL THEN
    SELECT email INTO v_email FROM auth.users WHERE id = v_actor;
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_action := 'member.added';
    v_target := COALESCE(NEW.user_id::text, NEW.email);
    v_org_id := NEW.org_id;
    v_meta := jsonb_build_object(
      'member_id', NEW.id,
      'email',     NEW.email,
      'role',      NEW.role,
      'status',    NEW.status,
      'source',    'rls'
    );
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      v_action := 'member.role_changed';
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
      v_action := 'member.status_changed';
    ELSE
      RETURN NEW;
    END IF;
    v_target := COALESCE(NEW.user_id::text, NEW.email);
    v_org_id := NEW.org_id;
    v_meta := jsonb_build_object(
      'member_id', NEW.id,
      'email',     NEW.email,
      'old_role',  OLD.role,
      'new_role',  NEW.role,
      'old_status', OLD.status,
      'new_status', NEW.status
    );
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'member.removed';
    v_target := COALESCE(OLD.user_id::text, OLD.email);
    v_org_id := OLD.org_id;
    v_meta := jsonb_build_object(
      'member_id', OLD.id,
      'email',     OLD.email,
      'role',      OLD.role
    );
  END IF;

  -- Skip the audit insert if the parent organization no longer exists
  -- (cascade-delete case). The org-level audit covers the high-level action.
  SELECT EXISTS(SELECT 1 FROM organizations WHERE id = v_org_id) INTO v_org_exists;
  IF NOT v_org_exists THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  INSERT INTO audit_logs (org_id, actor_user_id, actor_email, action, target_type, target_id, metadata)
  VALUES (v_org_id, v_actor, v_email, v_action, 'organization_member', v_target, v_meta);

  RETURN COALESCE(NEW, OLD);
END;
$$;
