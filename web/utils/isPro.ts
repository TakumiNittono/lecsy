// Centralized "is this user Pro?" check.
//
// A user is considered Pro if ANY of:
//   1) Their email is in WHITELIST_EMAILS env var (developer/comp access)
//   2) They have an individual Stripe subscription with status='active'
//   3) They are an active member of any organization on the 'pro' plan
//
// Use this everywhere that gates Pro features instead of hand-rolling
// the same predicate, otherwise B2B users will be shown "Upgrade" UIs
// even though their school already paid.

import type { SupabaseClient } from '@supabase/supabase-js'

const PAID_PLANS = ['pro'] as const

export interface ProStatus {
  isPro: boolean
  /** Specific source so the UI can show "Free / Personal Pro / via [School Name]" etc. */
  source: 'whitelist' | 'individual' | 'organization' | 'none'
  /** When source = 'organization', the org's name (for the badge in the UI). */
  orgName?: string
  /** Raw individual subscription, if any (kept for currentPeriodEnd display). */
  subscription?: {
    status: string | null
    current_period_end: string | null
    cancel_at_period_end: boolean | null
  } | null
}

export async function getProStatus(
  supabase: SupabaseClient,
  user: { id: string; email?: string | null }
): Promise<ProStatus> {
  // 1. Whitelist
  const whitelist = (process.env.WHITELIST_EMAILS ?? '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean)
  if (user.email && whitelist.includes(user.email.toLowerCase())) {
    return { isPro: true, source: 'whitelist' }
  }

  // 2. Individual Stripe subscription
  const { data: subscription } = await supabase
    .from('subscriptions')
    .select('status, current_period_end, cancel_at_period_end')
    .eq('user_id', user.id)
    .maybeSingle()

  if (subscription?.status === 'active') {
    return { isPro: true, source: 'individual', subscription }
  }

  // 3. Organization membership in a paid plan
  // Note: this query goes through RLS — the user can only see orgs they're
  // a member of, which is exactly what we want.
  const { data: orgMemberships } = await supabase
    .from('organization_members')
    .select('role, status, organizations(name, plan)')
    .eq('user_id', user.id)
    .eq('status', 'active')

  if (orgMemberships) {
    for (const m of orgMemberships) {
      // Supabase typing for joined relations is loose; defensively coerce.
      const org = (m as { organizations?: { name?: string; plan?: string } | null }).organizations
      if (org?.plan && (PAID_PLANS as readonly string[]).includes(org.plan)) {
        return {
          isPro: true,
          source: 'organization',
          orgName: org.name,
          subscription,
        }
      }
    }
  }

  return { isPro: false, source: 'none', subscription }
}
