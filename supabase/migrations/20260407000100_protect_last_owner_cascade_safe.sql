-- Fix: protect_last_owner trigger blocks legitimate DELETE FROM organizations
-- because cascade-delete on members fires BEFORE DELETE → trigger raises
-- 'cannot_delete_last_owner' even though the parent org is going away.
--
-- Behavior change: when the parent organization no longer exists (i.e., the
-- DELETE is part of a cascade from the org table), skip the last-owner check.
-- The org itself is being removed, so there's no orphaning concern.
--
-- Note: also drop the now-redundant force_delete_org RPC since natural DELETE
-- on organizations will work correctly.

CREATE OR REPLACE FUNCTION protect_last_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  remaining_owners INT;
  org_still_exists BOOLEAN;
BEGIN
  IF TG_OP = 'DELETE' AND OLD.role = 'owner' THEN
    -- Skip the check entirely if the parent org is being removed (cascade case).
    SELECT EXISTS(SELECT 1 FROM organizations WHERE id = OLD.org_id) INTO org_still_exists;
    IF NOT org_still_exists THEN
      RETURN OLD;
    END IF;

    SELECT count(*) INTO remaining_owners
      FROM organization_members
      WHERE org_id = OLD.org_id
        AND role = 'owner'
        AND id != OLD.id
        AND status = 'active';
    IF remaining_owners = 0 THEN
      RAISE EXCEPTION 'cannot_delete_last_owner';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.role = 'owner' AND NEW.role != 'owner' THEN
    SELECT count(*) INTO remaining_owners
      FROM organization_members
      WHERE org_id = OLD.org_id
        AND role = 'owner'
        AND id != OLD.id
        AND status = 'active';
    IF remaining_owners = 0 THEN
      RAISE EXCEPTION 'cannot_demote_last_owner';
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Update force_delete_org so it ALSO clears audit_logs first (FK to organizations)
-- and then relies on the now cascade-safe triggers. No more session_replication_role
-- (which requires superuser on Supabase managed Postgres).
CREATE OR REPLACE FUNCTION force_delete_org(p_org_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- audit_logs has a FK to organizations, must be cleared first
  DELETE FROM audit_logs WHERE org_id = p_org_id;
  -- Now the cascade-safe triggers handle the rest
  DELETE FROM organizations WHERE id = p_org_id;
END;
$$;
