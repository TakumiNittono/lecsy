// 共通: 認証/認可ヘルパ
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } }
  );
}

export function userClient(req: Request): SupabaseClient {
  const auth = req.headers.get('Authorization') ?? '';
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: auth } }, auth: { persistSession: false } }
  );
}

export async function requireUser(req: Request) {
  const sb = userClient(req);
  const { data: { user }, error } = await sb.auth.getUser();
  if (error || !user) throw new HttpError(401, 'unauthorized');
  return { user, sb };
}

export async function requireSuperAdmin(req: Request) {
  const { user } = await requireUser(req);
  const admin = adminClient();
  const { data, error } = await admin
    .from('super_admin_emails')
    .select('email')
    .eq('email', user.email!.toLowerCase())
    .maybeSingle();
  if (error || !data) throw new HttpError(403, 'forbidden_super_admin_only');
  return { user, admin };
}

export async function requireOrgRole(req: Request, orgId: string, minRole: 'student'|'teacher'|'admin'|'owner') {
  const { user } = await requireUser(req);
  const admin = adminClient();

  // Super admin bypass: super admins can operate on any org regardless of membership
  const { data: superAdmin } = await admin
    .from('super_admin_emails')
    .select('email')
    .eq('email', user.email!.toLowerCase())
    .maybeSingle();
  if (superAdmin) return { user, admin };

  const { data, error } = await admin
    .rpc('is_org_role_at_least', { p_org: orgId, p_user: user.id, p_min: minRole });
  if (error) throw new HttpError(500, error.message);
  if (!data) throw new HttpError(403, 'forbidden_insufficient_role');
  return { user, admin };
}

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export async function writeAudit(
  admin: SupabaseClient,
  orgId: string | null,
  actorId: string,
  actorEmail: string,
  action: string,
  targetType?: string,
  targetId?: string,
  metadata: Record<string, unknown> = {}
) {
  await admin.from('audit_logs').insert({
    org_id: orgId,
    actor_user_id: actorId,
    actor_email: actorEmail,
    action,
    target_type: targetType,
    target_id: targetId,
    metadata,
  });
}
