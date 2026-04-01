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

  // slug重複チェック
  const { data: existing } = await supabase
    .from('organizations')
    .select('id')
    .eq('slug', finalSlug)
    .single()

  if (existing) {
    return NextResponse.json({ error: 'This slug is already taken' }, { status: 409 })
  }

  // 組織作成
  const { data: org, error: orgError } = await supabase
    .from('organizations')
    .insert({
      name: name.trim(),
      slug: finalSlug,
      type,
    })
    .select('id, slug')
    .single()

  if (orgError) {
    console.error('Failed to create organization:', orgError)
    return NextResponse.json({ error: 'Failed to create organization' }, { status: 500 })
  }

  // 作成者をownerとして登録
  const { error: memberError } = await supabase
    .from('organization_members')
    .insert({
      org_id: org.id,
      user_id: user!.id,
      role: 'owner',
    })

  if (memberError) {
    console.error('Failed to add owner:', memberError)
    // ロールバック: 組織を削除
    await supabase.from('organizations').delete().eq('id', org.id)
    return NextResponse.json({ error: 'Failed to set up organization' }, { status: 500 })
  }

  return NextResponse.json({ slug: org.slug }, { status: 201 })
}
