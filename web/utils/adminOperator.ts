// Single source of truth for who can reach the /admin operator console.
// Locked to one email by design — no table lookup, no env var — so the
// only way to grant access is a code change. /admin/grant-ownership and
// /admin/super-admins both read from here, as does the middleware gate
// in front of /admin/*.

export const ADMIN_OPERATOR_EMAIL = 'nittonotakumi@gmail.com'

export function isAdminOperator(email: string | null | undefined): boolean {
  return !!email && email.toLowerCase() === ADMIN_OPERATOR_EMAIL
}
