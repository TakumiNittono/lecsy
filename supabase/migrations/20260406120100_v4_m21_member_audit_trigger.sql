-- v4 M21: organization_members 変更を audit_logs に自動記録
--
-- Captures direct (RLS-layer) inserts/updates/deletes that don't go through
-- an Edge Function — e.g. members added via the Supabase JS client by an
-- admin in /org/[slug]/members. Edge Functions still write their own audit
-- entries with richer metadata; this trigger is the safety net.

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
    -- Only audit role changes or status flips
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

  INSERT INTO audit_logs (org_id, actor_user_id, actor_email, action, target_type, target_id, metadata)
  VALUES (v_org_id, v_actor, v_email, v_action, 'organization_member', v_target, v_meta);

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_org_members ON organization_members;
CREATE TRIGGER trg_audit_org_members
  AFTER INSERT OR UPDATE OR DELETE ON organization_members
  FOR EACH ROW
  EXECUTE FUNCTION audit_organization_members();
