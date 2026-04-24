// supabase/functions/delete-account/index.ts
// Purpose: アカウント削除（Apple審査要件対応）

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';
import { alert } from '../_shared/alert.ts';

Deno.serve(async (req) => {
  // CORS プリフライト
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // 認証
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    // Service Role Keyを使ってユーザーを削除
    // これにより auth.users から削除され、ON DELETE CASCADE で関連データも削除される
    const { error: deleteError } = await serviceClient.auth.admin.deleteUser(
      user.id
    );

    if (deleteError) {
      console.error("Error deleting user:", deleteError.message);
      return createErrorResponse(req, "Failed to delete account", 500);
    }

    return createJsonResponse(req, { success: true });
  } catch (error) {
    const msg = error instanceof Error ? error.message : "Unknown error";
    console.error("Error:", msg);
    await alert({
      source: 'delete-account',
      level: 'critical',
      message: `delete_account_failed: ${msg}`,
      error,
    });
    return createErrorResponse(req, "Internal server error", 500);
  }
});
