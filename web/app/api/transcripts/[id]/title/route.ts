import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"
import { authenticateRequest, isValidUUID, validateOrigin } from "@/utils/api/auth"
import { checkRateLimit, getClientIdentifier, createRateLimitResponse } from "@/utils/rateLimit"

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
    const { user, error: authError } = await authenticateRequest()
    if (authError) return authError

    // レート制限チェック（1分間に30回まで）
    const identifier = getClientIdentifier(request, user!.id)
    const { allowed, remaining, resetAt } = checkRateLimit(identifier, 30, 60 * 1000)
    
    if (!allowed) {
      return createRateLimitResponse(remaining, resetAt) as NextResponse
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
    const supabase = createClient()

    // 更新を実行し、結果を確認
    const { data, error } = await supabase
      .from("transcripts")
      .update({ title, updated_at: new Date().toISOString() })
      .eq("id", id)
      .eq("user_id", user!.id)
      .select('id, title')
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return NextResponse.json(
          { error: "Transcript not found or access denied" },
          { status: 404 }
        )
      }
      console.error("Error updating transcript title:", error)
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
    console.error("Error in PATCH /api/transcripts/[id]/title:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
