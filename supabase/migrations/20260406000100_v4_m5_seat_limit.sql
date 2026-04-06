-- v4 M5: 座席上限のDBトリガー（race condition対策）

CREATE OR REPLACE FUNCTION enforce_seat_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  active_count INT;
  seat_limit INT;
BEGIN
  SELECT max_seats INTO seat_limit
    FROM organizations
    WHERE id = NEW.org_id;

  SELECT count(*) INTO active_count
    FROM organization_members
    WHERE org_id = NEW.org_id
      AND status IN ('active', 'pending');

  IF active_count >= seat_limit THEN
    RAISE EXCEPTION 'seat_limit_exceeded'
      USING HINT = format('Organization has reached its seat limit of %s', seat_limit);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_seats ON organization_members;
CREATE TRIGGER trg_enforce_seats
  BEFORE INSERT ON organization_members
  FOR EACH ROW
  EXECUTE FUNCTION enforce_seat_limit();

-- 最後のownerを保護するトリガー
CREATE OR REPLACE FUNCTION protect_last_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  remaining_owners INT;
BEGIN
  IF TG_OP = 'DELETE' AND OLD.role = 'owner' THEN
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

DROP TRIGGER IF EXISTS trg_protect_last_owner ON organization_members;
CREATE TRIGGER trg_protect_last_owner
  BEFORE UPDATE OR DELETE ON organization_members
  FOR EACH ROW
  EXECUTE FUNCTION protect_last_owner();
