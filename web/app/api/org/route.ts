import { createClient } from '@/utils/supabase/server'
import { authenticateRequest, validateOrigin } from '@/utils/api/auth'
import { NextResponse } from 'next/server'

const SLUG_REGEX = /^[a-z0-9][a-z0-9-]*[a-z0-9]$/

export async function POST(request: Request) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const { user, error: authError } = await authenticateRequest()
  if (authError) return authError

  const body = await request.json()
  const { name, type, slug } = body

  if (!name || typeof name !== 'string' || name.trim().length === 0 || name.length > 100) {
    return NextResponse.json({ error: 'Name is required (max 100 chars)' }, { status: 400 })
  }

  const validTypes = ['language_school', 'university_iep', 'college', 'corporate']
  if (!type || !validTypes.includes(type)) {
    return NextResponse.json({ error: 'Invalid organization type' }, { status: 400 })
  }

  const finalSlug = (slug || name)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 50)

  if (!finalSlug || finalSlug.length < 2) {
    return NextResponse.json({ error: 'Slug must be at least 2 characters' }, { status: 400 })
  }

  if (!SLUG_REGEX.test(finalSlug)) {
    return NextResponse.json({ error: 'Slug must contain only lowercase letters, numbers, and hyphens' }, { status: 400 })
  }

  const supabase = createClient()

  // DB関数で組織作成 + owner登録をアトミックに実行（RLSの鶏卵問題を回避）
  const { error: rpcError } = await supabase.rpc('create_organization', {
    p_name: name.trim(),
    p_slug: finalSlug,
    p_type: type,
  })

  if (rpcError) {
    console.error('Failed to create organization:', rpcError)
    if (rpcError.message?.includes('duplicate') || rpcError.message?.includes('unique')) {
      return NextResponse.json({ error: 'This slug is already taken' }, { status: 409 })
    }
    return NextResponse.json({ error: 'Failed to create organization' }, { status: 500 })
  }

  return NextResponse.json({ slug: finalSlug }, { status: 201 })
}
