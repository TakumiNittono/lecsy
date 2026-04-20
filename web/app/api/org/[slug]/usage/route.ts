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

  const startDate = new Date(start)
  const endDate = new Date(end)

  if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    return NextResponse.json({ error: 'Invalid date format' }, { status: 400 })
  }

  if (startDate > endDate) {
    return NextResponse.json({ error: 'start must be before end' }, { status: 400 })
  }

  const supabase = createAdminClient()

  // Fan out: members / org-level AI logs / classes all only depend on orgId,
  // so run them concurrently instead of serially before the userIds-gated
  // second wave.
  const [membersRes, orgAiLogsRes, classesRes] = await Promise.all([
    // ferpa_consented_at lets the dashboard prove to a Dean / compliance
    // officer that students acknowledged the consent prompt before any
    // audio was streamed.
    supabase
      .from('organization_members')
      .select('user_id, role, ferpa_consented_at')
      .eq('org_id', orgId),
    // Org-scoped AI actions (cross-summary, glossary generation).
    supabase
      .from('org_ai_usage_logs')
      .select('user_id, action, created_at')
      .eq('org_id', orgId)
      .gte('created_at', startDate.toISOString())
      .lte('created_at', endDate.toISOString()),
    supabase
      .from('org_classes')
      .select('id, name, archived')
      .eq('org_id', orgId),
  ])

  const { data: members, error: membersError } = membersRes

  if (membersError) {
    console.error('Failed to fetch members:', membersError)
    return NextResponse.json({ error: 'Failed to fetch members' }, { status: 500 })
  }

  if (!members || members.length === 0) {
    return NextResponse.json({
      summary: {
        total_recordings: 0,
        total_duration: 0,
        active_users: 0,
        total_users: 0,
        avg_duration_per_user: 0,
        total_summaries: 0,
        consented_users: 0,
      },
      members: [],
      classes: [],
    })
  }

  const userIds = members.map((m) => m.user_id)

  // Second wave: userIds-dependent queries. getUserById fan-out + per-user
  // transcripts + personal AI usage logs — all parallel.
  const [userInfoResults, transcriptsRes, usageLogsRes] = await Promise.all([
    Promise.all(
      userIds.map(async (uid) => {
        const { data } = await supabase.auth.admin.getUserById(uid)
        if (!data?.user) return [uid, null] as const
        const meta = data.user.user_metadata || {}
        return [
          uid,
          {
            email: data.user.email || '',
            name: meta.full_name || meta.name || '',
          },
        ] as const
      })
    ),
    supabase
      .from('transcripts')
      .select('user_id, duration, language, created_at, class_id')
      .in('user_id', userIds)
      .gte('created_at', startDate.toISOString())
      .lte('created_at', endDate.toISOString()),
    supabase
      .from('usage_logs')
      .select('user_id, action, created_at')
      .in('user_id', userIds)
      .gte('created_at', startDate.toISOString())
      .lte('created_at', endDate.toISOString()),
  ])

  const { data: transcripts, error: transcriptsError } = transcriptsRes
  if (transcriptsError) {
    console.error('Failed to fetch transcripts:', transcriptsError)
    return NextResponse.json({ error: 'Failed to fetch usage data' }, { status: 500 })
  }

  const userInfoMap = new Map<string, { email: string; name: string }>()
  for (const [uid, info] of userInfoResults) {
    if (info) userInfoMap.set(uid, info)
  }

  // Aggregate per user
  const userStatsMap = new Map<
    string,
    {
      transcript_count: number
      total_duration: number
      last_used: string | null
      languages: Set<string>
      summaries_generated: number
    }
  >()

  const ensure = (uid: string) => {
    let stats = userStatsMap.get(uid)
    if (!stats) {
      stats = {
        transcript_count: 0,
        total_duration: 0,
        last_used: null,
        languages: new Set(),
        summaries_generated: 0,
      }
      userStatsMap.set(uid, stats)
    }
    return stats
  }

  for (const t of transcripts || []) {
    const stats = ensure(t.user_id)
    stats.transcript_count++
    stats.total_duration += t.duration || 0
    if (t.language) stats.languages.add(t.language)
    if (!stats.last_used || t.created_at > stats.last_used) {
      stats.last_used = t.created_at
    }
  }

  // Personal AI: summarize/exam_mode both count toward "summaries generated"
  // since they represent "the user asked the AI to digest a lecture".
  for (const log of usageLogsRes.data || []) {
    const stats = ensure(log.user_id)
    stats.summaries_generated++
  }

  // Org-scoped AI: cross-summary / glossary both roll up as AI usage.
  for (const log of orgAiLogsRes.data || []) {
    if (!log.user_id) continue
    const stats = ensure(log.user_id)
    stats.summaries_generated++
  }

  // Build per-user response
  const membersList = members.map((m: any) => {
    const stats = userStatsMap.get(m.user_id)
    const userInfo = userInfoMap.get(m.user_id)
    return {
      user_id: m.user_id,
      email: userInfo?.email || '',
      name: userInfo?.name || '',
      role: m.role,
      recordings: stats?.transcript_count || 0,
      total_duration: stats?.total_duration || 0,
      last_used: stats?.last_used || null,
      languages: stats ? Array.from(stats.languages) : [],
      summaries_generated: stats?.summaries_generated || 0,
      ferpa_consented_at: m.ferpa_consented_at || null,
    }
  })

  // Per-class breakdown: group transcripts by class_id, skip nulls.
  const classMap = new Map<string, { name: string; archived: boolean }>()
  for (const row of classesRes.data || []) {
    classMap.set(row.id, { name: row.name, archived: !!row.archived })
  }

  const classAgg = new Map<
    string,
    { recordings: number; total_duration: number; active_users: Set<string> }
  >()
  let unassignedRecordings = 0
  let unassignedDuration = 0

  for (const t of transcripts || []) {
    if (!t.class_id) {
      unassignedRecordings++
      unassignedDuration += t.duration || 0
      continue
    }
    let bucket = classAgg.get(t.class_id)
    if (!bucket) {
      bucket = { recordings: 0, total_duration: 0, active_users: new Set() }
      classAgg.set(t.class_id, bucket)
    }
    bucket.recordings++
    bucket.total_duration += t.duration || 0
    bucket.active_users.add(t.user_id)
  }

  const classBreakdown = Array.from(classAgg.entries())
    .map(([classId, agg]) => ({
      class_id: classId,
      name: classMap.get(classId)?.name || '(deleted class)',
      archived: classMap.get(classId)?.archived || false,
      recordings: agg.recordings,
      total_duration: agg.total_duration,
      active_users: agg.active_users.size,
    }))
    .sort((a, b) => b.recordings - a.recordings)

  if (unassignedRecordings > 0) {
    classBreakdown.push({
      class_id: '',
      name: 'Unassigned',
      archived: false,
      recordings: unassignedRecordings,
      total_duration: unassignedDuration,
      active_users: 0,
    })
  }

  const totalRecordings = membersList.reduce((s, m) => s + m.recordings, 0)
  const totalDuration = membersList.reduce((s, m) => s + m.total_duration, 0)
  const totalSummaries = membersList.reduce((s, m) => s + m.summaries_generated, 0)
  const activeUsers = membersList.filter((m) => m.recordings > 0).length
  const totalUsers = membersList.length
  const consentedUsers = membersList.filter((m) => m.ferpa_consented_at).length

  return NextResponse.json({
    summary: {
      total_recordings: totalRecordings,
      total_duration: totalDuration,
      active_users: activeUsers,
      total_users: totalUsers,
      avg_duration_per_user: totalUsers > 0 ? Math.round(totalDuration / totalUsers) : 0,
      total_summaries: totalSummaries,
      consented_users: consentedUsers,
    },
    members: membersList,
    classes: classBreakdown,
  })
}
