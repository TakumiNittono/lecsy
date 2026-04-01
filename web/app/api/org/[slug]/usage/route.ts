import { requireOrgRole } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

export async function GET(
  request: Request,
  { params }: { params: { slug: string } }
) {
  const result = await requireOrgRole(params.slug, 'teacher')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const { searchParams } = new URL(request.url)
  const start = searchParams.get('start')
  const end = searchParams.get('end')

  if (!start || !end) {
    return NextResponse.json(
      { error: 'start and end query parameters are required (ISO date)' },
      { status: 400 }
    )
  }

  // Validate date formats
  const startDate = new Date(start)
  const endDate = new Date(end)

  if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    return NextResponse.json({ error: 'Invalid date format' }, { status: 400 })
  }

  if (startDate > endDate) {
    return NextResponse.json({ error: 'start must be before end' }, { status: 400 })
  }

  const supabase = createAdminClient()

  // Get all members
  const { data: members, error: membersError } = await supabase
    .from('organization_members')
    .select('user_id, role')
    .eq('org_id', orgId)

  if (membersError) {
    console.error('Failed to fetch members:', membersError)
    return NextResponse.json({ error: 'Failed to fetch members' }, { status: 500 })
  }

  if (!members || members.length === 0) {
    return NextResponse.json({ usage: [] })
  }

  const userIds = members.map(m => m.user_id)

  // Fetch user info via auth.admin
  const userInfoMap = new Map<string, { email: string; name: string }>()
  for (const uid of userIds) {
    const { data } = await supabase.auth.admin.getUserById(uid)
    if (data?.user) {
      const meta = data.user.user_metadata || {}
      userInfoMap.set(uid, {
        email: data.user.email || '',
        name: meta.full_name || meta.name || '',
      })
    }
  }

  // Get transcripts for these users in the date range
  const { data: transcripts, error: transcriptsError } = await supabase
    .from('transcripts')
    .select('user_id, duration, language, created_at')
    .in('user_id', userIds)
    .gte('created_at', startDate.toISOString())
    .lte('created_at', endDate.toISOString())

  if (transcriptsError) {
    console.error('Failed to fetch transcripts:', transcriptsError)
    return NextResponse.json({ error: 'Failed to fetch usage data' }, { status: 500 })
  }

  // Aggregate per user
  const userStatsMap = new Map<string, {
    transcript_count: number
    total_duration: number
    last_used: string | null
    languages: Set<string>
  }>()

  for (const t of transcripts || []) {
    let stats = userStatsMap.get(t.user_id)
    if (!stats) {
      stats = { transcript_count: 0, total_duration: 0, last_used: null, languages: new Set() }
      userStatsMap.set(t.user_id, stats)
    }
    stats.transcript_count++
    stats.total_duration += t.duration || 0
    if (t.language) stats.languages.add(t.language)
    if (!stats.last_used || t.created_at > stats.last_used) {
      stats.last_used = t.created_at
    }
  }

  // Build response
  const usage = members.map((m: any) => {
    const stats = userStatsMap.get(m.user_id)
    const userInfo = userInfoMap.get(m.user_id)
    return {
      user_id: m.user_id,
      email: userInfo?.email || '',
      name: userInfo?.name || '',
      role: m.role,
      transcript_count: stats?.transcript_count || 0,
      total_duration: stats?.total_duration || 0,
      last_used: stats?.last_used || null,
      languages: stats ? Array.from(stats.languages) : [],
    }
  })

  return NextResponse.json({ usage })
}
