-- v4 M20: seats_purchased + Stripe Quantity sync + enforcement
--
-- Semantics:
--   - max_seats:        manual cap set by super-admin (initial trial limit / hard ceiling).
--   - seats_purchased:  number of seats actually paid for via Stripe (line item Quantity).
--                       Synced by stripe-webhook on subscription.updated / .created.
--                       0 means "not yet purchased — fall back to max_seats".
--   - effective seat limit = seats_purchased when > 0, else max_seats.
--
-- The stripe-webhook function updates seats_purchased from
-- subscription.items.data[0].quantity. stripe_subscription_item_id is stored so
-- we can later PATCH the Quantity (proration) when admins add/remove seats.

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS seats_purchased INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stripe_subscription_item_id TEXT;

COMMENT ON COLUMN organizations.seats_purchased IS
  'Seats actually billed via Stripe (line item quantity). When > 0, overrides max_seats for enforcement. Synced by stripe-webhook.';
COMMENT ON COLUMN organizations.stripe_subscription_item_id IS
  'Stripe subscription item id, used to PATCH Quantity for seat add/remove with proration.';

-- Rewrite the seat-limit trigger to honour seats_purchased.
CREATE OR REPLACE FUNCTION enforce_seat_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  active_count INT;
  seat_limit   INT;
  v_max_seats  INT;
  v_purchased  INT;
BEGIN
  SELECT max_seats, COALESCE(seats_purchased, 0)
    INTO v_max_seats, v_purchased
    FROM organizations
    WHERE id = NEW.org_id;

  -- Effective seat limit: prefer purchased seats once any have been bought.
  IF v_purchased > 0 THEN
    seat_limit := v_purchased;
  ELSE
    seat_limit := v_max_seats;
  END IF;

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

-- Trigger already exists from M5; CREATE OR REPLACE FUNCTION above is enough.

-- Loosen the plan CHECK so stripe-webhook can mark a canceled subscription as 'free'
-- and so we can sync the new plan names ('business') used by org-checkout.
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_plan_check;
ALTER TABLE organizations
  ADD CONSTRAINT organizations_plan_check
  CHECK (plan IN ('free', 'starter', 'growth', 'business', 'enterprise'));
