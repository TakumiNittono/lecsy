import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

export async function PATCH(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const body = await request.json()
  const { name, logo_url } = body

  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length === 0 || name.length > 100) {
      return NextResponse.json(
        { error: 'Name is required (max 100 chars)' },
        { status: 400 }
      )
    }
  }

  if (logo_url !== undefined && logo_url !== null) {
    if (typeof logo_url !== 'string' || logo_url.length > 500) {
      return NextResponse.json(
        { error: 'Invalid logo_url (max 500 chars)' },
        { status: 400 }
      )
    }
    // Only accept URLs we control (our own Supabase Storage bucket).
    if (!/^https?:\/\/[^\s]+\/storage\/v1\/object\/public\/org-logos\//.test(logo_url)) {
      return NextResponse.json({ error: 'logo_url must be from org-logos bucket' }, { status: 400 })
    }
  }

  const updates: Record<string, any> = {}
  if (name !== undefined) updates.name = name.trim()
  if (logo_url !== undefined) updates.logo_url = logo_url

  if (Object.keys(updates).length === 0) {
    return NextResponse.json({ error: 'No valid fields to update' }, { status: 400 })
  }

  const supabase = createAdminClient()

  const { error: updateError } = await supabase
    .from('organizations')
    .update(updates)
    .eq('id', orgId)

  if (updateError) {
    console.error('Failed to update organization:', updateError)
    return NextResponse.json({ error: 'Failed to update organization' }, { status: 500 })
  }

  return NextResponse.json({ success: true })
}

export async function DELETE(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'owner')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const supabase = createAdminClient()

  const { error: deleteError } = await supabase
    .from('organizations')
    .delete()
    .eq('id', orgId)

  if (deleteError) {
    console.error('Failed to delete organization:', deleteError)
    return NextResponse.json({ error: 'Failed to delete organization' }, { status: 500 })
  }

  return NextResponse.json({ success: true })
}
