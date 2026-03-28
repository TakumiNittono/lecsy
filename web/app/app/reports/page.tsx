import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import ReportList from './ReportList'

export const dynamic = 'force-dynamic'

// 管理者メールリスト
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

  // 管理者RLSポリシーにより全レポートが取得可能
  const { data: reports, error: reportsError } = await supabase
    .from('reports')
    .select('*')
    .order('created_at', { ascending: false })

  if (reportsError) {
    console.error('Failed to fetch reports:', reportsError)
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
        <ReportList initialReports={reports || []} />
      </div>
    </main>
  )
}
