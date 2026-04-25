// /admin operator access is locked to a single hardcoded email — see
// utils/adminOperator.ts. The legacy `super_admin_emails` table lookup
// has been removed: even if someone INSERTs another email into the
// table (or the table is wiped), the gate stays under code review.

import { isAdminOperator } from './adminOperator'

export async function isSuperAdmin(email: string | null | undefined): Promise<boolean> {
  return isAdminOperator(email)
}
