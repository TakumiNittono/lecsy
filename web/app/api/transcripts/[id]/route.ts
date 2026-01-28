import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"
import { authenticateRequest, isValidUUID, validateOrigin } from "@/utils/api/auth"
import { checkRateLimit, getClientIdentifier, createRateLimitResponse } from "@/utils/rateLimit"

// 動的レンダリングを強制（認証が必要なAPI、動的パラメータ）
export const dynamic = 'force-dynamic'

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    
    // Origin/Referer検証（CSRF対策）
    if (!validateOrigin(request)) {
      return NextResponse.json(
        { error: "Forbidden" },
        { status: 403 }
      )
    }
    
    // ID形式のバリデーション
    if (!isValidUUID(id)) {
      return NextResponse.json(
        { error: "Invalid ID format" },
        { status: 400 }
      )
    }

    // 認証チェック
    const { user, error: authError } = await authenticateRequest()
    if (authError) return authError

    // レート制限チェック（1時間に20回まで）
    const identifier = getClientIdentifier(request, user!.id)
    const { allowed, remaining, resetAt } = checkRateLimit(identifier, 20, 60 * 60 * 1000)
    
    if (!allowed) {
      return createRateLimitResponse(remaining, resetAt) as NextResponse
    }

    const supabase = createClient()

    // 削除を実行し、結果を確認
    const { data, error } = await supabase
      .from("transcripts")
      .delete()
      .eq("id", id)
      .eq("user_id", user!.id)
      .select('id')  // 削除されたレコードを返す
      .single()

    if (error) {
      // レコードが見つからない場合
      if (error.code === 'PGRST116') {
        return NextResponse.json(
          { error: "Transcript not found or access denied" },
          { status: 404 }
        )
      }
      console.error("Error deleting transcript:", error)
      return NextResponse.json(
        { error: "Failed to delete transcript" },
        { status: 500 }
      )
    }

    // 削除が成功したかを確認
    if (!data) {
      return NextResponse.json(
        { error: "Transcript not found or access denied" },
        { status: 404 }
      )
    }

    return NextResponse.json({ success: true, deletedId: data.id })
  } catch (error) {
    console.error("Error in DELETE /api/transcripts/[id]:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
