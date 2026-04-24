// org-grant-ownership: スーパー管理者のみ、特定組織にownerを付与
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createPreflightResponse, createJsonResponse, createErrorResponse } from '../_shared/cors.ts';
import { requireSuperAdmin, writeAudit, HttpError } from '../_shared/auth.ts';
import { alert } from '../_shared/alert.ts';

interface Payload {
  org_id: string;
  email: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const { user, admin } = await requireSuperAdmin(req);
    const body: Payload = await req.json();

    if (!body.org_id || !body.email) throw new HttpError(400, 'missing_fields');
    const email = body.email.toLowerCase().trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'invalid_email');

    // 既存メンバーがいるか確認
    const { data: existing } = await admin
      .from('organization_members')
      .select('id, role, status, user_id')
      .eq('org_id', body.org_id)
      .or(`email.eq.${email},user_id.in.(${await getUserIdByEmail(admin, email)})`)
      .maybeSingle();

    if (existing) {
      // 既存のロールを owner に昇格
      const { error } = await admin
        .from('organization_members')
        .update({ role: 'owner' })
        .eq('id', existing.id);
      if (error) throw new HttpError(500, error.message);

      await writeAudit(admin, body.org_id, user.id, user.email!, 'org.grant_ownership', 'member', existing.id, { email });
      return createJsonResponse(req, { ok: true, action: 'promoted', member_id: existing.id });
    }

    // 新規追加
    const { data: created, error } = await admin
      .from('organization_members')
      .insert({ org_id: body.org_id, email, role: 'owner', status: 'pending' })
      .select()
      .single();
    if (error) throw new HttpError(500, error.message);

    await writeAudit(admin, body.org_id, user.id, user.email!, 'org.grant_ownership', 'member', created.id, { email, status: 'pending' });
    return createJsonResponse(req, { ok: true, action: 'created', member_id: created.id });
  } catch (e) {
    if (e instanceof HttpError) return createErrorResponse(req, e.message, e.status);
    await alert({
      source: 'org-grant-ownership',
      level: 'error',
      message: `org_grant_ownership internal_error: ${(e as Error).message}`,
      error: e,
    });
    return createErrorResponse(req, 'internal_error', 500);
  }
});

async function getUserIdByEmail(admin: any, email: string): Promise<string> {
  const { data } = await admin.auth.admin.listUsers();
  const u = data?.users?.find((x: any) => x.email?.toLowerCase() === email);
  return u?.id ?? '00000000-0000-0000-0000-000000000000';
}
