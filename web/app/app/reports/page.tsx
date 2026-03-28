import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import ReportList from './ReportList'

export const dynamic = 'force-dynamic'

// 管理者メールリスト（環境変数から取得）
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

  // 全レポートを取得（管理者はservice_roleではなくRLSバイパスではないので、
  // 直接Supabaseから取得するにはadmin APIが必要。
  // ここではREST APIでservice_roleを使わず、全ユーザーのレポートを表示するため
  // supabase adminクライアントの代わりにRPCまたは特別なポリシーを使う）
  // → 管理者用のRLSポリシーを追加するか、API routeを使う
  // ここではAPI route経由で取得する
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
        <ReportList adminEmail={user.email || ''} />
      </div>
    </main>
  )
}
