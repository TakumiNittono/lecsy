// org-create: スーパー管理者のみ組織を作成する
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createPreflightResponse, createJsonResponse, createErrorResponse } from '../_shared/cors.ts';
import { requireSuperAdmin, writeAudit, HttpError } from '../_shared/auth.ts';

interface CreateOrgPayload {
  name: string;
  slug: string;
  type?: 'language_school' | 'university_iep' | 'college' | 'corporate';
  plan?: 'free' | 'pro';
  max_seats?: number;
  owner_email?: string;
  allowed_email_domains?: string[];
  locale?: string;
  timezone?: string;
}

const SLUG_RE = /^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$/;

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const { user, admin } = await requireSuperAdmin(req);
    const body: CreateOrgPayload = await req.json();

    // バリデーション
    if (!body.name || body.name.trim().length === 0 || body.name.length > 100) {
      throw new HttpError(400, 'invalid_name');
    }
    if (!body.slug || !SLUG_RE.test(body.slug)) {
      throw new HttpError(400, 'invalid_slug');
    }
    const maxSeats = body.max_seats ?? 50;
    if (maxSeats < 1 || maxSeats > 100000) {
      throw new HttpError(400, 'invalid_max_seats');
    }

    // 組織を作成
    const { data: org, error: orgErr } = await admin
      .from('organizations')
      .insert({
        name: body.name.trim(),
        slug: body.slug.toLowerCase(),
        type: body.type ?? 'language_school',
        plan: body.plan ?? 'pro',
        max_seats: maxSeats,
        allowed_email_domains: body.allowed_email_domains ?? [],
        locale: body.locale ?? 'en',
        timezone: body.timezone ?? 'UTC',
      })
      .select()
      .single();

    if (orgErr) {
      if (orgErr.code === '23505') throw new HttpError(409, 'slug_already_exists');
      throw new HttpError(500, orgErr.message);
    }

    // owner を pending メンバーとして追加（ログイン時に active 化）+ 招待メール送信
    if (body.owner_email) {
      const ownerEmail = body.owner_email.toLowerCase().trim();
      const { error: memErr } = await admin
        .from('organization_members')
        .insert({
          org_id: org.id,
          email: ownerEmail,
          role: 'owner',
          status: 'pending',
        });
      if (memErr) {
        return createJsonResponse(req, {
          organization: org,
          warning: `owner_add_failed: ${memErr.message}`,
        }, 201);
      }

      // 招待メール送信 (best-effort): send-org-invite Edge Function に集約。
      // 自分自身を呼び出す形になるが、Supabase Functions runtime は同一プロジェクト
      // 内の関数間呼び出しを問題なく扱う。
      try {
        await admin.functions.invoke('send-org-invite', {
          body: { org_id: org.id, email: ownerEmail },
        });
      } catch {
        // Pending 行は作れているので無視。Apple/Google サインインで自動 active 化。
      }
    }

    await writeAudit(admin, org.id, user.id, user.email!, 'org.create', 'organization', org.id, {
      slug: org.slug,
      plan: org.plan,
      max_seats: maxSeats,
    });

    return createJsonResponse(req, { organization: org }, 201);
  } catch (e) {
    if (e instanceof HttpError) return createErrorResponse(req, e.message, e.status);
    return createErrorResponse(req, 'internal_error', 500);
  }
});
