-- Bulletproof auto-activation: any time a row appears in auth.users
-- (sign-up via Web, iOS, magic link, OAuth, anything) we look up matching
-- pending org_members by email and flip them to active.
--
-- This removes the dependency on application code (Web auth callback or
-- iOS PostLoginCoordinator) remembering to call activate_pending_memberships
-- after every sign-in. If a new auth path is added later, this still works.

CREATE OR REPLACE FUNCTION public.trigger_activate_pending_memberships()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.email IS NULL THEN
        RETURN NEW;
    END IF;

    UPDATE public.organization_members
    SET user_id = NEW.id,
        status  = 'active'
    WHERE email = lower(NEW.email)
      AND status = 'pending'
      AND user_id IS NULL;

    RETURN NEW;
END;
$$;

-- Drop existing triggers if re-running
DROP TRIGGER IF EXISTS on_auth_user_insert_activate_pending  ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_update_activate_pending  ON auth.users;

-- Fires on initial sign-up
CREATE TRIGGER on_auth_user_insert_activate_pending
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.trigger_activate_pending_memberships();

-- Fires when email is set later (e.g. Apple's hidden email getting confirmed,
-- or any UPDATE that touches the email column)
CREATE TRIGGER on_auth_user_update_activate_pending
AFTER UPDATE OF email ON auth.users
FOR EACH ROW
WHEN (NEW.email IS DISTINCT FROM OLD.email)
EXECUTE FUNCTION public.trigger_activate_pending_memberships();

-- Backfill: activate any existing pending rows whose email matches an
-- already-signed-up auth.users row. Fixes users currently stuck Pending.
UPDATE public.organization_members om
SET user_id = u.id,
    status  = 'active'
FROM auth.users u
WHERE om.status = 'pending'
  AND om.user_id IS NULL
  AND om.email IS NOT NULL
  AND lower(om.email) = lower(u.email);
