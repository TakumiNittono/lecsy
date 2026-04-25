import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { isSuperAdmin } from '@/utils/isSuperAdmin'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import GrantOwnershipButton from './GrantOwnershipButton'

export const dynamic = 'force-dynamic'

const DAY_MS = 24 * 60 * 60 * 1000
const RECENT_TX_LIMIT = 30
const TOP_USERS_LIMIT = 10
const ACTIVITY_WINDOW_DAYS = 30

function formatRelativeTime(iso: string | null | undefined): string {
  if (!iso) return 'Never'
  const ms = new Date(iso).getTime()
  if (!ms) return 'Never'
  const diff = Date.now() - ms
  if (diff < 0) return 'just now'
  if (diff < 60_000) return 'just now'
  if (diff < 3600_000) return `${Math.floor(diff / 60_000)}m ago`
  if (diff < 86_400_000) return `${Math.floor(diff / 3600_000)}h ago`
  if (diff < 7 * 86_400_000) return `${Math.floor(diff / 86_400_000)}d ago`
  return new Date(iso).toLocaleDateString()
}

function formatDuration(seconds: number | null | undefined): string {
  const s = Math.max(0, Math.round(Number(seconds) || 0))
  if (s === 0) return '—'
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m`
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  return m === 0 ? `${h}h` : `${h}h ${m}m`
}

function formatHours(seconds: number): string {
  if (!seconds) return '0h'
  const hours = seconds / 3600
  if (hours < 0.1) return `${Math.round(seconds / 60)}m`
  if (hours < 10) return `${hours.toFixed(1)}h`
  return `${Math.round(hours)}h`
}

export default async function AdminPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user || !(await isSuperAdmin(user.email))) {
    redirect('/app')
  }

  // service_role クライアント（RLS バイパス）で全データ取得
  const admin = createAdminClient()

  const now = Date.now()
  const since24h = new Date(now - DAY_MS).toISOString()
  const since7d = new Date(now - 7 * DAY_MS).toISOString()
  const sinceWindow = new Date(now - ACTIVITY_WINDOW_DAYS * DAY_MS).toISOString()

  // 並列で取得 — 全部 head/limit 付きなので RLS バイパスでも軽い
  const [
    orgsRes,
    memberCountsRes,
    transcriptCountRes,
    subsRes,
    betaOrgRes,
    recentTxRes,
    tx24hCountRes,
    tx7dCountRes,
    txWindowRes,
    usersRes,
  ] = await Promise.all([
    admin.from('organizations').select('*').order('created_at', { ascending: false }),
    admin.from('organization_members').select('org_id, user_id'),
    admin.from('transcripts').select('*', { count: 'exact', head: true }),
    admin.from('subscriptions').select('status'),
    admin.from('organizations').select('id, slug, name').eq('slug', 'lecsy-beta').maybeSingle(),
    admin
      .from('transcripts')
      .select('id, user_id, title, duration, language, source, created_at')
      .order('created_at', { ascending: false })
      .limit(RECENT_TX_LIMIT),
    admin.from('transcripts').select('*', { count: 'exact', head: true }).gte('created_at', since24h),
    admin.from('transcripts').select('*', { count: 'exact', head: true }).gte('created_at', since7d),
    admin
      .from('transcripts')
      .select('user_id, duration, created_at, language')
      .gte('created_at', sinceWindow),
    // listUsers は 1 リクエストでメール / last_sign_in_at をまとめて取れる。
    // 現状の登録人数なら 1 ページで十分。1000 を超えたらページネーション
    // を足す。
    admin.auth.admin.listUsers({ perPage: 1000 }),
  ])

  const orgs = orgsRes.data || []
  const memberCounts = memberCountsRes.data || []
  const transcriptCount = transcriptCountRes.count ?? 0
  const subs = subsRes.data || []
  const betaOrg = betaOrgRes.data
  const recentTx = recentTxRes.data || []
  const tx24h = tx24hCountRes.count ?? 0
  const tx7d = tx7dCountRes.count ?? 0
  const txWindow = txWindowRes.data || []
  const allUsers = usersRes.data?.users || []

  const countByOrg: Record<string, number> = {}
  memberCounts.forEach((m: any) => {
    countByOrg[m.org_id] = (countByOrg[m.org_id] || 0) + 1
  })

  const activeSubs = subs.filter((s: any) => s.status === 'active').length
  const totalSubs = subs.length

  const { count: betaMemberCount } = betaOrg
    ? await admin
        .from('organization_members')
        .select('id', { count: 'exact', head: true })
        .eq('org_id', betaOrg.id)
        .eq('status', 'active')
    : { count: 0 }

  // ユーザーのメール / 最終ログインを map 化
  const emailByUid = new Map<string, string>()
  const lastSignInByUid = new Map<string, string>()
  for (const u of allUsers) {
    if (u.email) emailByUid.set(u.id, u.email)
    if (u.last_sign_in_at) lastSignInByUid.set(u.id, u.last_sign_in_at)
  }

  // 30 日ウィンドウのユーザー集計 (録音回数 / 合計秒数 / 直近録音時刻 / 言語数)
  type UserStat = {
    user_id: string
    count: number
    seconds: number
    lastTxAt: string | null
    languages: Set<string>
  }
  const statsByUid = new Map<string, UserStat>()
  let totalWindowSeconds = 0
  for (const t of txWindow as any[]) {
    if (!t.user_id) continue
    const cur = statsByUid.get(t.user_id) || {
      user_id: t.user_id,
      count: 0,
      seconds: 0,
      lastTxAt: null,
      languages: new Set<string>(),
    }
    cur.count += 1
    cur.seconds += Number(t.duration) || 0
    if (!cur.lastTxAt || t.created_at > cur.lastTxAt) cur.lastTxAt = t.created_at
    if (t.language) cur.languages.add(t.language)
    statsByUid.set(t.user_id, cur)
    totalWindowSeconds += Number(t.duration) || 0
  }
  const activeUsers30d = statsByUid.size

  const topUsers = [...statsByUid.values()]
    .sort((a, b) => b.seconds - a.seconds || b.count - a.count)
    .slice(0, TOP_USERS_LIMIT)

  // Top users の "last seen" は max(transcript.created_at, auth.last_sign_in_at)
  const lastSeenForUid = (uid: string): string | null => {
    const tx = statsByUid.get(uid)?.lastTxAt || null
    const sign = lastSignInByUid.get(uid) || null
    if (tx && sign) return tx > sign ? tx : sign
    return tx || sign
  }

  // 全登録ユーザーのうち、30日以内に何らかのアクティビティ (sign-in or 録音) があった数
  const liveLast30d = allUsers.filter((u) => {
    const last = lastSeenForUid(u.id)
    if (!last) return false
    return new Date(last).getTime() >= now - ACTIVITY_WINDOW_DAYS * DAY_MS
  }).length

  const handleSignOut = async () => {
    'use server'
    const supabase = createClient()
    await supabase.auth.signOut()
    redirect('/admin/login')
  }

  return (
    <main className="min-h-screen bg-gray-50" data-dashboard>
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
              lecsy
            </Link>
            <span className="text-xs px-2 py-1 rounded-full bg-red-100 text-red-700 font-medium">
              Super Admin
            </span>
          </div>
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-sm text-gray-600 hover:text-gray-900">Dashboard</Link>
            <Link href="/app/reports" className="text-sm text-gray-600 hover:text-gray-900">Reports</Link>
            <Link href="/admin/super-admins" className="text-sm text-gray-600 hover:text-gray-900">Super Admins</Link>
            <span className="text-gray-700 text-sm">{user.email}</span>
            <form action={handleSignOut}>
              <button type="submit" className="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors font-medium">
                Logout
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Platform Admin</h1>
        <p className="text-gray-600 mb-8">Manage all organizations and users across Lecsy.</p>

        {/* Lecsy Beta Testers — Private beta access */}
        {betaOrg && (
          <div className="mb-8 rounded-xl border-2 border-blue-500 bg-gradient-to-r from-blue-50 to-indigo-50 p-6">
            <div className="flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-2xl">🧪</span>
                  <h2 className="text-xl font-bold text-gray-900">Lecsy Beta Testers</h2>
                  <span className="rounded-full bg-blue-600 px-2 py-0.5 text-xs font-bold text-white">
                    PRO
                  </span>
                </div>
                <p className="text-sm text-gray-700">
                  Private beta access for friends. Members get full Pro features (Deepgram live captions + translation).
                  Currently <span className="font-bold">{betaMemberCount ?? 0}</span> active member(s).
                </p>
              </div>
              <div className="flex gap-2">
                <Link
                  href={`/org/${betaOrg.slug}/members`}
                  className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 transition-colors"
                >
                  Manage Members →
                </Link>
                <Link
                  href={`/org/${betaOrg.slug}/members/import`}
                  className="rounded-lg border border-blue-600 px-4 py-2 text-sm font-semibold text-blue-600 hover:bg-blue-50 transition-colors"
                >
                  Add by CSV
                </Link>
              </div>
            </div>
          </div>
        )}

        {/* Stats — totals */}
        <div className="grid md:grid-cols-4 gap-6 mb-6">
          <StatCard label="Organizations" value={orgs.length} accent="purple" />
          <StatCard label="Total Members" value={memberCounts.length} accent="blue" />
          <StatCard label="Active Subscriptions" value={`${activeSubs} / ${totalSubs}`} accent="green" />
          <StatCard label="Total Transcripts" value={transcriptCount} accent="amber" />
        </div>

        {/* Stats — activity (last N days) */}
        <div className="grid md:grid-cols-4 gap-6 mb-8">
          <StatCard label="Recordings · 24h" value={tx24h} accent="indigo" />
          <StatCard label="Recordings · 7d" value={tx7d} accent="indigo" />
          <StatCard label={`Hours · ${ACTIVITY_WINDOW_DAYS}d`} value={formatHours(totalWindowSeconds)} accent="rose" />
          <StatCard label={`Active users · ${ACTIVITY_WINDOW_DAYS}d`} value={`${activeUsers30d} / ${allUsers.length}`} accent="emerald" sub={`live ${liveLast30d}`} />
        </div>

        {/* Top users + Recent activity (2 column on desktop) */}
        <div className="grid lg:grid-cols-2 gap-6 mb-8">
          <section className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="p-5 border-b border-gray-200 flex items-center justify-between">
              <h2 className="text-base font-semibold text-gray-900">Top users · last {ACTIVITY_WINDOW_DAYS}d</h2>
              <span className="text-xs text-gray-500">by recorded time</span>
            </div>
            {topUsers.length === 0 ? (
              <div className="p-6 text-sm text-gray-500">No recordings in this window yet.</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 text-xs uppercase text-gray-500">
                    <tr>
                      <th className="text-left px-4 py-2">User</th>
                      <th className="text-right px-4 py-2">Recs</th>
                      <th className="text-right px-4 py-2">Time</th>
                      <th className="text-left px-4 py-2">Last seen</th>
                    </tr>
                  </thead>
                  <tbody>
                    {topUsers.map((u) => {
                      const email = emailByUid.get(u.user_id) || u.user_id.slice(0, 8) + '…'
                      const last = lastSeenForUid(u.user_id)
                      return (
                        <tr key={u.user_id} className="border-t border-gray-100">
                          <td className="px-4 py-3 text-gray-900 break-all">{email}</td>
                          <td className="px-4 py-3 text-right text-gray-700">{u.count}</td>
                          <td className="px-4 py-3 text-right text-gray-700">{formatDuration(u.seconds)}</td>
                          <td className="px-4 py-3 text-gray-500">{formatRelativeTime(last)}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="p-5 border-b border-gray-200 flex items-center justify-between">
              <h2 className="text-base font-semibold text-gray-900">Recent activity</h2>
              <span className="text-xs text-gray-500">last {RECENT_TX_LIMIT} recordings</span>
            </div>
            {recentTx.length === 0 ? (
              <div className="p-6 text-sm text-gray-500">No transcripts saved to the cloud yet.</div>
            ) : (
              <div className="overflow-x-auto max-h-[480px] overflow-y-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 text-xs uppercase text-gray-500 sticky top-0">
                    <tr>
                      <th className="text-left px-4 py-2">When</th>
                      <th className="text-left px-4 py-2">User</th>
                      <th className="text-left px-4 py-2">Title</th>
                      <th className="text-right px-4 py-2">Dur</th>
                      <th className="text-left px-4 py-2">Lang</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentTx.map((t: any) => {
                      const email = t.user_id ? (emailByUid.get(t.user_id) || t.user_id.slice(0, 8) + '…') : 'anon'
                      return (
                        <tr key={t.id} className="border-t border-gray-100">
                          <td className="px-4 py-3 text-gray-500 whitespace-nowrap" title={new Date(t.created_at).toLocaleString()}>
                            {formatRelativeTime(t.created_at)}
                          </td>
                          <td className="px-4 py-3 text-gray-900 break-all">{email}</td>
                          <td className="px-4 py-3 text-gray-700 max-w-[18ch] truncate" title={t.title || ''}>
                            {t.title || '—'}
                          </td>
                          <td className="px-4 py-3 text-right text-gray-700">{formatDuration(t.duration)}</td>
                          <td className="px-4 py-3 text-gray-500 uppercase">{t.language || '—'}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>

        {/* Organizations List */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200">
          <div className="p-6 border-b border-gray-200 flex justify-between items-center">
            <h2 className="text-lg font-semibold text-gray-900">All Organizations</h2>
            <Link
              href="/org/new"
              className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
            >
              + New Organization
            </Link>
          </div>

          {orgs.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200 bg-gray-50">
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Name</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Plan</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Members</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Created</th>
                    <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {orgs.map((org: any) => (
                    <tr key={org.id} className="border-b border-gray-100 hover:bg-gray-50">
                      <td className="px-6 py-4">
                        <Link href={`/org/${org.slug}`} className="font-medium text-blue-600 hover:text-blue-800">
                          {org.name}
                        </Link>
                        <p className="text-xs text-gray-400">{org.slug}</p>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-600 capitalize">{org.type.replace('_', ' ')}</span>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                          org.plan === 'enterprise' ? 'bg-purple-100 text-purple-700' :
                          org.plan === 'growth' ? 'bg-blue-100 text-blue-700' :
                          'bg-gray-100 text-gray-700'
                        } capitalize`}>
                          {org.plan}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-900">{countByOrg[org.id] || 0} / {org.max_seats}</span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-500">
                          {new Date(org.created_at).toLocaleDateString()}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-4">
                          <Link
                            href={`/org/${org.slug}`}
                            className="text-sm text-blue-600 hover:text-blue-800"
                          >
                            Manage
                          </Link>
                          <GrantOwnershipButton orgId={org.id} orgName={org.name} />
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="p-12 text-center">
              <p className="text-gray-500">No organizations yet.</p>
            </div>
          )}
        </div>

        <p className="mt-6 text-xs text-gray-400">
          Data is fetched fresh on each load. Cmd+R to refresh. Activity windows are rolling
          ({ACTIVITY_WINDOW_DAYS}d / 7d / 24h) computed from <code>transcripts.created_at</code> and
          <code> auth.users.last_sign_in_at</code>. Deepgram realtime minute counters
          (<code>user_*_realtime_usage</code>) exist as caps but are not yet incremented client-side
          — wire that up to surface live minutes here.
        </p>
      </div>
    </main>
  )
}

function StatCard({
  label,
  value,
  accent,
  sub,
}: {
  label: string
  value: string | number
  accent: 'purple' | 'blue' | 'green' | 'amber' | 'indigo' | 'rose' | 'emerald'
  sub?: string
}) {
  const accentMap: Record<string, string> = {
    purple: 'bg-purple-100 text-purple-700',
    blue: 'bg-blue-100 text-blue-700',
    green: 'bg-green-100 text-green-700',
    amber: 'bg-amber-100 text-amber-700',
    indigo: 'bg-indigo-100 text-indigo-700',
    rose: 'bg-rose-100 text-rose-700',
    emerald: 'bg-emerald-100 text-emerald-700',
  }
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-medium text-gray-500">{label}</h2>
        <span className={`text-[10px] uppercase tracking-wider px-2 py-0.5 rounded-full ${accentMap[accent]}`}>
          live
        </span>
      </div>
      <p className="text-3xl font-bold text-gray-900">{value}</p>
      {sub && <p className="mt-1 text-xs text-gray-500">{sub}</p>}
    </div>
  )
}
