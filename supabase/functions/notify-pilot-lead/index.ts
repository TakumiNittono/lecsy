// notify-pilot-lead: /schools/demo フォーム送信時にファウンダーへ通知メールを送る
//
// 設計:
//   - 認証: service_role 前提（Web の /api/schools/demo から admin.functions.invoke）
//   - pilot_leads.id を受け取り、Row を読んで Resend 経由でメール送信
//   - Resend 未設定時はログだけ吐いて 200 を返す（Lead 自体は DB に残るので営業は継続可能）
//
// 参考: supabase/functions/send-org-invite/index.ts の構造をそのまま踏襲

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createPreflightResponse, createJsonResponse, createErrorResponse } from '../_shared/cors.ts';

const FROM_ADDR = Deno.env.get('RESEND_FROM') ?? 'Lecsy <noreply@lecsy.app>';
const TO_ADDR = Deno.env.get('PILOT_LEAD_NOTIFY_TO') ?? 'founder@lecsy.app';

function esc(s: string | null | undefined): string {
  if (!s) return '';
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

interface Payload {
  lead_id: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return createPreflightResponse(req);
  if (req.method !== 'POST') return createErrorResponse(req, 'method_not_allowed', 405);

  try {
    const body: Payload = await req.json();
    if (!body.lead_id) {
      return createErrorResponse(req, 'missing_lead_id', 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) {
      return createErrorResponse(req, 'server_misconfigured', 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: lead, error } = await admin
      .from('pilot_leads')
      .select('id, school_name, contact_name, contact_email, role, phone, notes, created_at')
      .eq('id', body.lead_id)
      .single();

    if (error || !lead) {
      return createErrorResponse(req, 'lead_not_found', 404);
    }

    const resendKey = Deno.env.get('RESEND_API_KEY');
    if (!resendKey) {
      console.log(`[notify-pilot-lead] No RESEND_API_KEY configured. Lead ${lead.id} stored only.`);
      return createJsonResponse(req, { ok: true, sent: false, reason: 'resend_not_configured' }, 200);
    }

    const subject = `New pilot lead: ${lead.school_name}`;
    const html = `
<!doctype html>
<html><body style="font-family:-apple-system,Segoe UI,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#0B1E3F">
  <h2 style="margin:0 0 12px">New pilot request</h2>
  <p style="margin:0 0 20px;color:#4A5B74">Submitted ${new Date(lead.created_at).toLocaleString('en-US', { timeZone: 'America/New_York' })} ET</p>

  <table style="width:100%;border-collapse:collapse">
    <tr><td style="padding:6px 0;width:140px;color:#8A9BB5;font-size:12px;text-transform:uppercase">School</td><td style="padding:6px 0"><strong>${esc(lead.school_name)}</strong></td></tr>
    <tr><td style="padding:6px 0;color:#8A9BB5;font-size:12px;text-transform:uppercase">Contact</td><td style="padding:6px 0">${esc(lead.contact_name)}</td></tr>
    <tr><td style="padding:6px 0;color:#8A9BB5;font-size:12px;text-transform:uppercase">Email</td><td style="padding:6px 0"><a href="mailto:${esc(lead.contact_email)}">${esc(lead.contact_email)}</a></td></tr>
    <tr><td style="padding:6px 0;color:#8A9BB5;font-size:12px;text-transform:uppercase">Role</td><td style="padding:6px 0">${esc(lead.role)}</td></tr>
    ${lead.phone ? `<tr><td style="padding:6px 0;color:#8A9BB5;font-size:12px;text-transform:uppercase">Phone</td><td style="padding:6px 0">${esc(lead.phone)}</td></tr>` : ''}
  </table>

  ${lead.notes ? `
    <h3 style="margin:24px 0 8px;font-size:14px;color:#8A9BB5;text-transform:uppercase;letter-spacing:0.05em">Notes</h3>
    <p style="margin:0;white-space:pre-line;line-height:1.6">${esc(lead.notes)}</p>
  ` : ''}

  <hr style="border:none;border-top:1px solid #E5E1D8;margin:28px 0">
  <p style="font-size:12px;color:#8A9BB5;margin:0">Lead ID: ${lead.id}</p>
</body></html>`.trim();

    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM_ADDR,
        to: [TO_ADDR],
        reply_to: lead.contact_email,
        subject,
        html,
      }),
    });

    if (!resendRes.ok) {
      const errBody = await resendRes.text();
      console.error(`[notify-pilot-lead] Resend failed: ${resendRes.status} ${errBody}`);
      return createJsonResponse(req, { ok: true, sent: false, reason: 'resend_failed' }, 200);
    }

    return createJsonResponse(req, { ok: true, sent: true }, 200);
  } catch (e) {
    console.error('[notify-pilot-lead] error', e);
    return createErrorResponse(req, `internal_error: ${(e as Error).message}`, 500);
  }
});
