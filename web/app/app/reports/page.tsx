import { createClient } from '@/utils/supabase/server'
import { createClient as createServiceClient } from '@supabase/supabase-js'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import ReportList from './ReportList'

export const dynamic = 'force-dynamic'

function getAdminEmails(): string[] {
  const whitelist = process.env.WHITELIST_EMAILS || ''
  return whitelist.split(',').map(e => e.trim()).filter(Boolean)
}

export default async function ReportsPage() {
  const supabase = createClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/login')
  }

  // 管理者チェック
  const adminEmails = getAdminEmails()
  const isAdmin = !!(user.email && adminEmails.includes(user.email))

  if (!isAdmin) {
    redirect('/app')
  }

  // service_role クライアントで全レポート取得（サーバーサイドのみ・RLSバイパス）
  const serviceUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  let reports: any[] = []
  let reportsError: string | null = null

  if (serviceUrl && serviceKey) {
    const adminClient = createServiceClient(serviceUrl, serviceKey)
    const { data, error: fetchError } = await adminClient
      .from('reports')
      .select('*')
      .order('created_at', { ascending: false })

    if (fetchError) {
      console.error('Failed to fetch reports:', fetchError)
      reportsError = fetchError.message
    } else {
      reports = data || []
    }
  } else {
    // フォールバック: ユーザーのクライアントで取得（RLS適用）
    console.warn('SUPABASE_SERVICE_ROLE_KEY not set, falling back to user client')
    const { data, error: fetchError } = await supabase
      .from('reports')
      .select('*')
      .order('created_at', { ascending: false })

    if (fetchError) {
      console.error('Failed to fetch reports:', fetchError)
      reportsError = fetchError.message
    } else {
      reports = data || []
    }
  }

  return (
    <main className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
              lecsy
            </Link>
            <span className="text-gray-400">/</span>
            <h1 className="text-lg font-semibold text-gray-900">Reports</h1>
          </div>
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-sm text-gray-600 hover:text-gray-900 transition-colors">
              Dashboard
            </Link>
            <span className="text-gray-700 text-sm">{user.email}</span>
          </div>
        </div>
      </header>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {reportsError ? (
          <div className="bg-red-50 border border-red-200 rounded-xl p-6 mb-6">
            <p className="text-red-700 text-sm">Error: {reportsError}</p>
            <p className="text-red-500 text-xs mt-1">
              {!serviceKey ? 'SUPABASE_SERVICE_ROLE_KEY is not configured in Vercel.' : 'Database query failed.'}
            </p>
          </div>
        ) : null}
        <ReportList initialReports={reports} />
      </div>
    </main>
  )
}
