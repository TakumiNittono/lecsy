import { NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { requireOrgRole } from '@/utils/api/org-auth'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const MAX_BYTES = 512 * 1024 // 512KB
const ALLOWED_MIME = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])

/**
 * POST /api/org/[slug]/logo
 * multipart/form-data with field `file`.
 * Uploads to Supabase Storage bucket `org-logos`, then updates
 * organizations.logo_url to the public URL.
 */
export async function POST(
  req: Request,
  { params }: { params: { slug: string } }
) {
  const auth = await requireOrgRole(params.slug, 'admin')
  if (auth instanceof NextResponse) return auth
  const { orgId, org } = auth

  let form: FormData
  try {
    form = await req.formData()
  } catch {
    return NextResponse.json({ error: 'invalid_form' }, { status: 400 })
  }

  const file = form.get('file')
  if (!(file instanceof File)) {
    return NextResponse.json({ error: 'file_required' }, { status: 400 })
  }
  if (file.size === 0) {
    return NextResponse.json({ error: 'empty_file' }, { status: 400 })
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json(
      { error: 'file_too_large', max_bytes: MAX_BYTES },
      { status: 413 }
    )
  }
  if (!ALLOWED_MIME.has(file.type)) {
    return NextResponse.json(
      { error: 'invalid_mime_type', allowed: Array.from(ALLOWED_MIME) },
      { status: 415 }
    )
  }

  const admin = createAdminClient()

  const ext = file.type.split('/')[1]?.replace('+xml', '').replace('jpeg', 'jpg') ?? 'bin'
  const objectPath = `${org.slug}/${Date.now()}.${ext}`

  const { error: upErr } = await admin.storage
    .from('org-logos')
    .upload(objectPath, file, {
      contentType: file.type,
      upsert: false,
      cacheControl: '3600',
    })

  if (upErr) {
    return NextResponse.json({ error: `upload_failed: ${upErr.message}` }, { status: 500 })
  }

  const { data: pub } = admin.storage.from('org-logos').getPublicUrl(objectPath)
  const publicUrl = pub.publicUrl

  const { error: updErr } = await admin
    .from('organizations')
    .update({ logo_url: publicUrl })
    .eq('id', orgId)

  if (updErr) {
    // Best-effort cleanup of the orphan object
    await admin.storage.from('org-logos').remove([objectPath])
    return NextResponse.json({ error: `db_update_failed: ${updErr.message}` }, { status: 500 })
  }

  return NextResponse.json({ ok: true, logo_url: publicUrl })
}

/**
 * DELETE /api/org/[slug]/logo
 * Clears organizations.logo_url. Doesn't aggressively purge old objects
 * (storage cleanup can be a weekly cron; not part of MVP).
 */
export async function DELETE(
  _req: Request,
  { params }: { params: { slug: string } }
) {
  const auth = await requireOrgRole(params.slug, 'admin')
  if (auth instanceof NextResponse) return auth
  const { orgId } = auth

  const admin = createAdminClient()
  const { error } = await admin
    .from('organizations')
    .update({ logo_url: null })
    .eq('id', orgId)

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
