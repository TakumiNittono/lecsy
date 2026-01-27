import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"

// 動的レンダリングを強制（認証が必要なAPI、動的パラメータ）
export const dynamic = 'force-dynamic'

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { title } = await request.json()

    if (!title || typeof title !== "string") {
      return NextResponse.json({ error: "Title is required" }, { status: 400 })
    }

    // タイトルを更新
    const { error } = await supabase
      .from("transcripts")
      .update({ title: title.trim() })
      .eq("id", id)
      .eq("user_id", user.id)

    if (error) {
      console.error("Error updating title:", error)
      return NextResponse.json({ error: "Failed to update title" }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error("Error in PATCH /api/transcripts/[id]/title:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
