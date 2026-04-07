-- Admin helper: force-delete an organization, bypassing protect_last_owner
-- and audit cascade FK constraints. Intended for super-admin cleanup of
-- abandoned trial orgs from the dashboard.
--
-- Usage (service_role only via RPC):
--   SELECT force_delete_org('00000000-...');

CREATE OR REPLACE FUNCTION force_delete_org(p_org_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Disable triggers for this transaction so cascade-delete can run
  -- without firing protect_last_owner / audit checks.
  SET LOCAL session_replication_role = replica;

  -- Clean up audit_logs first (FK constraint to organizations)
  DELETE FROM audit_logs WHERE org_id = p_org_id;

  -- Cascade delete will handle members, classes, glossaries, etc.
  DELETE FROM organizations WHERE id = p_org_id;
END;
$$;

-- Restrict execution: only service_role can run this (super-admin gate
-- happens at the application layer).
REVOKE EXECUTE ON FUNCTION force_delete_org(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION force_delete_org(UUID) FROM authenticated;
REVOKE EXECUTE ON FUNCTION force_delete_org(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION force_delete_org(UUID) TO service_role;
