// Centralized "is this user Pro?" check.
//
// Access policy (memo.md フェーズ1, 2026-04-15〜):
//   Free が default。Stripe sub / Beta org member (lecsy-beta) のみ Pro 扱い。
//   キャンペーン全員Pro昇格は撤廃。
//
// Edge Function側 (deepgram-token, translate-realtime) と一致させる必要あり。

import type { SupabaseClient } from '@supabase/supabase-js'

/** レガシー: キャンペーン終了日時 (まだ参照してる箇所の互換用。実機能は死んでる) */
export const CAMPAIGN_END_ISO = '2026-06-01T00:00:00+09:00'

export function isCampaignActive(_now: Date = new Date()): boolean {
  // 撤廃済 — 常に false
  return false
}

export interface ProStatus {
  isPro: boolean
  /** Source of Pro status */
  source: 'free-for-all' | 'whitelist' | 'individual' | 'organization' | 'none'
  /** When source = 'organization', the org's name (for the badge in the UI). */
  orgName?: string
  /** Raw individual subscription, if any (kept for currentPeriodEnd display). */
  subscription?: {
    status: string | null
    current_period_end: string | null
    cancel_at_period_end: boolean | null
  } | null
  /** Deprecated: always false */
  campaignActive?: boolean
  campaignEndsAt?: string
}

export async function getProStatus(
  supabase: SupabaseClient,
  user: { id: string; email?: string | null }
): Promise<ProStatus> {
  // 個人 Stripe サブスク
  const { data: subscription } = await supabase
    .from('subscriptions')
    .select('status, current_period_end, cancel_at_period_end')
    .eq('user_id', user.id)
    .maybeSingle()

  const hasActiveSub =
    subscription?.status === 'active' || subscription?.status === 'trialing'

  if (hasActiveSub) {
    return {
      isPro: true,
      source: 'individual',
      subscription,
      campaignActive: false,
      campaignEndsAt: CAMPAIGN_END_ISO,
    }
  }

  // Beta / B2B org member チェック
  const { data: orgMember } = await supabase
    .from('organization_members')
    .select('organizations!inner(plan, name)')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .limit(1)
    .maybeSingle()

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const org = (orgMember as any)?.organizations
  if (org?.plan === 'pro') {
    return {
      isPro: true,
      source: 'organization',
      orgName: org.name as string | undefined,
      subscription,
      campaignActive: false,
      campaignEndsAt: CAMPAIGN_END_ISO,
    }
  }

  return {
    isPro: false,
    source: 'none',
    subscription,
    campaignActive: false,
    campaignEndsAt: CAMPAIGN_END_ISO,
  }
}
