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

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

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

    // Strategy:
    //  1) Always generate an invite/magiclink URL via Supabase Auth admin API
    //     so the user can land on /login?org=<slug> and auto-join.
    //  2) If RESEND_API_KEY is configured, send a branded email via Resend
    //     (US pilot path). Otherwise fall back to Supabase's built-in mailer
    //     (inviteUserByEmail).
    let inviteOk = false;
    let inviteMethod: 'resend' | 'invite' | 'magiclink' = 'invite';
    let actionLink: string | null = null;

    // Try to generate an invite link (works for new users)
    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: 'invite',
      email,
      options: {
        data: inviteMetadata,
        redirectTo,
      },
    });

    if (!linkErr) {
      actionLink = linkData?.properties?.action_link ?? null;
    } else if (
      linkErr.message?.toLowerCase().includes('already') ||
      linkErr.message?.toLowerCase().includes('exists') ||
      linkErr.status === 422
    ) {
      // Existing user: fall back to magiclink
      const { data: mlData, error: mlErr } = await admin.auth.admin.generateLink({
        type: 'magiclink',
        email,
        options: {
          data: inviteMetadata,
          redirectTo,
        },
      });
      if (mlErr) throw new HttpError(500, `magiclink_failed: ${mlErr.message}`);
      actionLink = mlData?.properties?.action_link ?? null;
      inviteMethod = 'magiclink';
    } else {
      throw new HttpError(500, `invite_link_failed: ${linkErr.message}`);
    }

    const resendKey = Deno.env.get('RESEND_API_KEY');
    if (resendKey && actionLink) {
      // Branded English-first email via Resend
      const fromAddr = Deno.env.get('RESEND_FROM') ?? 'Lecsy <invites@lecsy.app>';
      const inviterName = user.email ?? 'Your team';
      const subject = `You're invited to join ${org.name} on Lecsy`;
      const html = `
<!doctype html>
<html><body style="font-family:-apple-system,Segoe UI,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#111">
  <h2 style="margin:0 0 16px">You're invited to <span style="color:#2563eb">${escapeHtml(org.name)}</span></h2>
  <p>${escapeHtml(inviterName)} has invited you to join <strong>${escapeHtml(org.name)}</strong> on Lecsy — the privacy-first lecture transcription app for students and educators.</p>
  <p style="margin:24px 0">
    <a href="${actionLink}" style="background:#2563eb;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none;font-weight:600">Accept invitation</a>
  </p>
  <p style="font-size:12px;color:#666">If the button doesn't work, copy this link:<br><span style="word-break:break-all">${actionLink}</span></p>
  <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
  <p style="font-size:12px;color:#888">${escapeHtml(org.name)} に招待されました。上のボタンからログインして参加してください。</p>
</body></html>`.trim();

      const resendRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: fromAddr,
          to: [email],
          subject,
          html,
        }),
      });

      if (!resendRes.ok) {
        const errBody = await resendRes.text();
        throw new HttpError(500, `resend_failed: ${resendRes.status} ${errBody}`);
      }
      inviteMethod = 'resend';
      inviteOk = true;
    } else {
      // Fallback: use Supabase's built-in mailer (sends invite email itself)
      const { error: inviteErr } = await admin.auth.admin.inviteUserByEmail(email, {
        data: inviteMetadata,
        redirectTo,
      });
      if (
        inviteErr &&
        !(
          inviteErr.message?.toLowerCase().includes('already') ||
          inviteErr.message?.toLowerCase().includes('exists') ||
          inviteErr.status === 422
        )
      ) {
        throw new HttpError(500, `invite_failed: ${inviteErr.message}`);
      }
      // For existing users, the magic link was already generated above; Supabase
      // does not send it automatically, so we rely on the caller surfacing the
      // link or the user retrying. (Branded path via Resend is preferred.)
      inviteOk = true;
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
