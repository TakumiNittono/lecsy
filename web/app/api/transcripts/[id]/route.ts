import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"
import { isValidUUID, validateOrigin } from "@/utils/api/auth"
import { checkRateLimit, createRateLimitResponse } from "@/utils/rateLimit"

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
    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return NextResponse.json(
        { error: "Unauthorized" },
        { status: 401 }
      )
    }

    // レート制限チェック（1時間に20回まで）
    const { allowed } = await checkRateLimit(supabase, user.id, 'delete_transcript', 20, 60 * 60 * 1000)
    if (!allowed) {
      return createRateLimitResponse() as NextResponse
    }

    // 削除を実行し、結果を確認
    const { data, error } = await supabase
      .from("transcripts")
      .delete()
      .eq("id", id)
      .eq("user_id", user.id)
      .select('id')
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return NextResponse.json(
          { error: "Transcript not found or access denied" },
          { status: 404 }
        )
      }
      console.error("Error deleting transcript:", error.message)
      return NextResponse.json(
        { error: "Failed to delete transcript" },
        { status: 500 }
      )
    }

    if (!data) {
      return NextResponse.json(
        { error: "Transcript not found or access denied" },
        { status: 404 }
      )
    }

    return NextResponse.json({ success: true, deletedId: data.id })
  } catch (error) {
    console.error("Error in DELETE /api/transcripts/[id]:", error instanceof Error ? error.message : "Unknown error")
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
