import { getOrgMembership } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'
import CrossSummaryPanel from './CrossSummaryPanel'
import GlossaryPanel from './GlossaryPanel'

export const dynamic = 'force-dynamic'

export default async function OrgAiPage({
  params,
}: {
  params: { slug: string }
}) {
  const membership = await getOrgMembership(params.slug)
  if (!membership) redirect('/app')

  const supabase = createAdminClient()
  const { orgId, org, role } = membership

  // 組織メンバーのトランスクリプト一覧（選択用）
  const { data: members } = await supabase
    .from('organization_members')
    .select('user_id')
    .eq('org_id', orgId)

  const memberIds = members?.map(m => m.user_id) || []

  let transcripts: Array<{ id: string; title: string; language: string | null; created_at: string }> = []
  if (memberIds.length > 0) {
    const { data } = await supabase
      .from('transcripts')
      .select('id, title, language, created_at')
      .in('user_id', memberIds)
      .order('created_at', { ascending: false })
      .limit(100)

    transcripts = data || []
  }

  // 現在の用語集数
  const { count: glossaryCount } = await supabase
    .from('org_glossaries')
    .select('*', { count: 'exact', head: true })
    .eq('org_id', orgId)

  // 今日のAI使用回数
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const { count: todayUsage } = await supabase
    .from('org_ai_usage_logs')
    .select('*', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .gte('created_at', today.toISOString())

  const planLimits: Record<string, number> = { starter: 10, growth: 50, enterprise: 200 }
  const dailyLimit = planLimits[org.plan] || 10

  return (
    <div className="px-6 lg:px-10 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">AI Assist</h1>
        <p className="text-gray-500 mt-1">
          B2B exclusive AI-powered tools for your organization
        </p>
      </div>

      {/* Usage Bar */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-5 mb-8">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <span className="text-sm font-medium text-gray-700">Daily AI Usage</span>
            <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize ${
              org.plan === 'enterprise' ? 'bg-purple-100 text-purple-700' :
              org.plan === 'growth' ? 'bg-blue-100 text-blue-700' :
              'bg-gray-100 text-gray-700'
            }`}>
              {org.plan}
            </span>
          </div>
          <span className="text-sm text-gray-500">
            {todayUsage || 0} / {dailyLimit} requests today
          </span>
        </div>
        <div className="w-full bg-gray-100 rounded-full h-2">
          <div
            className={`h-2 rounded-full transition-all ${
              ((todayUsage || 0) / dailyLimit) > 0.8 ? 'bg-red-500' : 'bg-blue-500'
            }`}
            style={{ width: `${Math.min(((todayUsage || 0) / dailyLimit) * 100, 100)}%` }}
          />
        </div>
      </div>

      {/* Feature Cards */}
      <div className="grid lg:grid-cols-2 gap-8">
        {/* Cross-Language Summary */}
        <CrossSummaryPanel
          slug={params.slug}
          transcripts={transcripts}
        />

        {/* Glossary Generator */}
        <GlossaryPanel
          slug={params.slug}
          transcripts={transcripts}
          glossaryCount={glossaryCount || 0}
          role={role}
        />
      </div>
    </div>
  )
}
