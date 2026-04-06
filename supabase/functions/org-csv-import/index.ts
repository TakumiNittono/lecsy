// org-csv-import: admin以上が org_id 配下にメンバーを一括追加
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createPreflightResponse, createJsonResponse, createErrorResponse } from '../_shared/cors.ts';
import { requireOrgRole, writeAudit, HttpError } from '../_shared/auth.ts';

interface Row {
  email: string;
  role?: 'student' | 'teacher' | 'admin';
  display_name?: string;
}
interface Payload {
  org_id: string;
  rows: Row[];
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const body: Payload = await req.json();
    if (!body.org_id || !Array.isArray(body.rows)) throw new HttpError(400, 'invalid_payload');
    if (body.rows.length === 0) throw new HttpError(400, 'empty_rows');
    if (body.rows.length > 1000) throw new HttpError(400, 'too_many_rows');

    const { user, admin } = await requireOrgRole(req, body.org_id, 'admin');

    // 組織情報を取得（ドメイン制限・座席上限）
    const { data: org, error: orgErr } = await admin
      .from('organizations')
      .select('id, max_seats, allowed_email_domains')
      .eq('id', body.org_id)
      .single();
    if (orgErr || !org) throw new HttpError(404, 'org_not_found');

    const { count: currentCount } = await admin
      .from('organization_members')
      .select('id', { count: 'exact', head: true })
      .eq('org_id', body.org_id)
      .in('status', ['active', 'pending']);

    const seatsAvailable = org.max_seats - (currentCount ?? 0);
    const allowedDomains: string[] = org.allowed_email_domains ?? [];

    const successes: Array<{ email: string; status: string }> = [];
    const failures: Array<{ row: number; email: string; reason: string }> = [];

    let used = 0;
    for (let i = 0; i < body.rows.length; i++) {
      const r = body.rows[i];
      const email = r.email?.toLowerCase().trim();
      const role = r.role ?? 'student';

      if (!email || !EMAIL_RE.test(email)) {
        failures.push({ row: i + 1, email: r.email ?? '', reason: 'invalid_email' });
        continue;
      }
      if (!['student', 'teacher', 'admin'].includes(role)) {
        failures.push({ row: i + 1, email, reason: 'invalid_role' });
        continue;
      }
      if (allowedDomains.length > 0) {
        const dom = email.split('@')[1];
        if (!allowedDomains.includes(dom)) {
          failures.push({ row: i + 1, email, reason: 'domain_not_allowed' });
          continue;
        }
      }
      if (used >= seatsAvailable) {
        failures.push({ row: i + 1, email, reason: 'seat_limit_exceeded' });
        continue;
      }

      const { error } = await admin
        .from('organization_members')
        .insert({ org_id: body.org_id, email, role, status: 'pending' });

      if (error) {
        if (error.code === '23505') {
          failures.push({ row: i + 1, email, reason: 'duplicate' });
        } else if (error.message?.includes('seat_limit_exceeded')) {
          failures.push({ row: i + 1, email, reason: 'seat_limit_exceeded' });
        } else {
          failures.push({ row: i + 1, email, reason: error.message });
        }
        continue;
      }
      successes.push({ email, status: 'pending' });
      used++;
    }

    await writeAudit(admin, body.org_id, user.id, user.email!, 'org.csv_import', 'organization', body.org_id, {
      total: body.rows.length,
      successes: successes.length,
      failures: failures.length,
    });

    return createJsonResponse(req, { successes, failures, summary: { total: body.rows.length, ok: successes.length, ng: failures.length } });
  } catch (e) {
    if (e instanceof HttpError) return createErrorResponse(req, e.message, e.status);
    return createErrorResponse(req, 'internal_error', 500);
  }
});
