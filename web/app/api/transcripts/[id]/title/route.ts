import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"
import { isValidUUID, validateOrigin } from "@/utils/api/auth"
import { checkRateLimit, createRateLimitResponse } from "@/utils/rateLimit"

// 動的レンダリングを強制（認証が必要なAPI、動的パラメータ）
export const dynamic = 'force-dynamic'

// タイトルのバリデーション
const MAX_TITLE_LENGTH = 200
const validateTitle = (title: unknown): { valid: boolean; error?: string } => {
  if (typeof title !== 'string') {
    return { valid: false, error: 'Title must be a string' }
  }
  if (title.trim().length === 0) {
    return { valid: false, error: 'Title cannot be empty' }
  }
  if (title.length > MAX_TITLE_LENGTH) {
    return { valid: false, error: `Title cannot exceed ${MAX_TITLE_LENGTH} characters` }
  }
  return { valid: true }
}

export async function PATCH(
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

    // レート制限チェック（1分間に30回まで）
    const { allowed } = await checkRateLimit(supabase, user.id, 'update_title', 30, 60 * 1000)
    if (!allowed) {
      return createRateLimitResponse() as NextResponse
    }

    // リクエストボディのパース
    let body: { title?: unknown }
    try {
      body = await request.json()
    } catch {
      return NextResponse.json(
        { error: "Invalid JSON body" },
        { status: 400 }
      )
    }

    // タイトルのバリデーション
    const titleValidation = validateTitle(body.title)
    if (!titleValidation.valid) {
      return NextResponse.json(
        { error: titleValidation.error },
        { status: 400 }
      )
    }

    const title = (body.title as string).trim()

    // 更新を実行し、結果を確認
    const { data, error } = await supabase
      .from("transcripts")
      .update({ title, updated_at: new Date().toISOString() })
      .eq("id", id)
      .eq("user_id", user.id)
      .select('id, title')
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return NextResponse.json(
          { error: "Transcript not found or access denied" },
          { status: 404 }
        )
      }
      console.error("Error updating transcript title:", error.message)
      return NextResponse.json(
        { error: "Failed to update title" },
        { status: 500 }
      )
    }

    if (!data) {
      return NextResponse.json(
        { error: "Transcript not found or access denied" },
        { status: 404 }
      )
    }

    return NextResponse.json({ success: true, data })
  } catch (error) {
    console.error("Error in PATCH /api/transcripts/[id]/title:", error instanceof Error ? error.message : "Unknown error")
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
