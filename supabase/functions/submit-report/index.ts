// supabase/functions/submit-report/index.ts
// Purpose: iOSアプリ・Webからの問題報告受付

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';

interface SubmitReportRequest {
  category: string;
  title: string;
  description: string;
  email?: string;
  device_info?: string;
  app_version?: string;
  platform?: string;
}

const VALID_CATEGORIES = ['bug', 'crash', 'feature', 'transcription', 'sync', 'account', 'other'];

serve(async (req) => {
  // CORS プリフライト
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    const body: SubmitReportRequest = await req.json();

    // バリデーション
    if (!body.description || body.description.trim() === "") {
      return createErrorResponse(req, "Description is required", 400);
    }
    if (!body.title || body.title.trim() === "") {
      return createErrorResponse(req, "Title is required", 400);
    }
    if (!VALID_CATEGORIES.includes(body.category)) {
      return createErrorResponse(req, `Invalid category. Must be one of: ${VALID_CATEGORIES.join(', ')}`, 400);
    }

    // 認証チェック（オプショナル — 未ログインでも送信可能）
    let userId: string | null = null;
    let userEmail: string | null = body.email || null;

    const authHeader = req.headers.get("Authorization");
    if (authHeader) {
      const supabaseAuth = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authHeader } } }
      );
      const { data: { user } } = await supabaseAuth.auth.getUser();
      if (user) {
        userId = user.id;
        userEmail = userEmail || user.email || null;
      }
    }

    // service_role で挿入（RLSバイパス — 未ログインユーザーからの報告も保存）
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data, error } = await supabaseAdmin
      .from("reports")
      .insert({
        user_id: userId,
        email: userEmail,
        category: body.category,
        title: body.title,
        description: body.description,
        device_info: body.device_info || null,
        app_version: body.app_version || null,
        platform: body.platform || 'ios',
        status: 'open',
      })
      .select("id, created_at")
      .single();

    if (error) {
      console.error("Insert error:", error.message);
      throw error;
    }

    return createJsonResponse(req, {
      id: data.id,
      message: "Report submitted successfully",
    });
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : "Unknown error");
    return createErrorResponse(req, "Failed to submit report", 500);
  }
});
