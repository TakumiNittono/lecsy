// send-org-invite: 組織管理者が pending メンバーを追加した際の招待メール送信
//
// 設計:
//   - 認証: 呼び出し元は org の admin 以上 (requireOrgRole)
//   - メール送信: Supabase Auth 内蔵の inviteUserByEmail を使用 (外部サービス不要)
//     - 既にユーザーが auth.users に存在する場合: フォールバックで magic link を送る
//   - メタデータ: メールに org_id / org_name を埋め込んで、サインイン後に
//     activate_pending_memberships で自動ジョインさせる
//   - 冪等: 同じ email を複数回呼ぶと毎回新しい magic link が送られる
//
// 呼び出し元想定:
//   - Web 管理画面 /org/[slug]/members/page.tsx の「メンバー追加」アクション
//   - iOS MemberListView の addMember 後
//
// 注: このファンクションは pending membership の挿入は行わない (重複防止のため
//     クライアント側で既存の REST INSERT → このファンクション呼び出し、の順)。

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createPreflightResponse, createJsonResponse, createErrorResponse } from '../_shared/cors.ts';
import { requireOrgRole, HttpError } from '../_shared/auth.ts';

interface InvitePayload {
  org_id: string;
  email: string;
  // Optional: where the invite link should land. Default = web admin login.
  redirect_to?: string;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const body: InvitePayload = await req.json();
    if (!body.org_id) throw new HttpError(400, 'invalid_org_id');
    if (!body.email || !EMAIL_RE.test(body.email)) throw new HttpError(400, 'invalid_email');

    const email = body.email.toLowerCase().trim();

    // 認可: admin/owner のみ
    const { user, admin } = await requireOrgRole(req, body.org_id, 'admin');

    // 組織情報を取得（メールの本文に名前を出すため）
    const { data: org, error: orgErr } = await admin
      .from('organizations')
      .select('id, name, slug, allowed_email_domains')
      .eq('id', body.org_id)
      .single();
    if (orgErr || !org) throw new HttpError(404, 'org_not_found');

    // ドメイン制限チェック (Edge Function 側でも明示的に検証)
    const domains: string[] = org.allowed_email_domains ?? [];
    if (domains.length > 0) {
      const emailDomain = email.split('@')[1];
      if (!domains.includes(emailDomain)) {
        throw new HttpError(403, 'domain_not_allowed');
      }
    }

    // pending メンバー行が実在するか確認 (招待のみが暴発しないように)
    const { data: pending, error: pendErr } = await admin
      .from('organization_members')
      .select('id, status')
      .eq('org_id', body.org_id)
      .eq('email', email)
      .maybeSingle();
    if (pendErr) throw new HttpError(500, pendErr.message);
    if (!pending) {
      throw new HttpError(404, 'pending_membership_not_found');
    }

    const redirectTo = body.redirect_to ?? `https://www.lecsy.app/login?org=${encodeURIComponent(org.slug)}`;
    const inviteMetadata = {
      org_id: org.id,
      org_name: org.name,
      org_slug: org.slug,
      invited_by: user.email,
    };

    // まず inviteUserByEmail を試す (新規ユーザー用)
    let inviteOk = false;
    let inviteMethod = 'invite';
    const { error: inviteErr } = await admin.auth.admin.inviteUserByEmail(email, {
      data: inviteMetadata,
      redirectTo,
    });

    if (!inviteErr) {
      inviteOk = true;
    } else if (
      inviteErr.message?.toLowerCase().includes('already') ||
      inviteErr.message?.toLowerCase().includes('exists') ||
      inviteErr.status === 422
    ) {
      // 既存ユーザー: magic link にフォールバック
      inviteMethod = 'magiclink';
      const { error: linkErr } = await admin.auth.admin.generateLink({
        type: 'magiclink',
        email,
        options: {
          data: inviteMetadata,
          redirectTo,
        },
      });
      if (!linkErr) {
        inviteOk = true;
      } else {
        throw new HttpError(500, `magiclink_failed: ${linkErr.message}`);
      }
    } else {
      throw new HttpError(500, `invite_failed: ${inviteErr.message}`);
    }

    // audit
    await admin.from('audit_logs').insert({
      org_id: org.id,
      actor_user_id: user.id,
      actor_email: user.email,
      action: 'member.invite_email_sent',
      target_type: 'organization_member',
      target_id: pending.id,
      metadata: { email, method: inviteMethod },
    });

    return createJsonResponse(req, { ok: inviteOk, method: inviteMethod, email }, 200);
  } catch (e) {
    if (e instanceof HttpError) return createErrorResponse(req, e.message, e.status);
    return createErrorResponse(req, `internal_error: ${(e as Error).message}`, 500);
  }
});
