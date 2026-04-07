// Single source of truth for super admin check.
// Mirrors the Edge Function side (supabase/functions/_shared/auth.ts)
// which queries the same `super_admin_emails` table via service_role.
//
// To add a super admin: INSERT INTO super_admin_emails (email) VALUES ('...');
// (Done once via the Supabase SQL editor — no code change needed.)

import { createAdminClient } from '@/utils/supabase/admin'

export async function isSuperAdmin(email: string | null | undefined): Promise<boolean> {
  if (!email) return false
  const admin = createAdminClient()
  const { data } = await admin
    .from('super_admin_emails')
    .select('email')
    .eq('email', email.toLowerCase())
    .maybeSingle()
  return !!data
}
