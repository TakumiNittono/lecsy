import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { isSuperAdmin } from '@/utils/isSuperAdmin'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import SuperAdminsClient from './SuperAdminsClient'

export const dynamic = 'force-dynamic'

export default async function SuperAdminsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user || !(await isSuperAdmin(user.email))) {
    redirect('/app')
  }

  const admin = createAdminClient()
  const { data: rows } = await admin
    .from('super_admin_emails')
    .select('email, note, created_at')
    .order('created_at', { ascending: true })

  return (
    <main className="min-h-screen bg-gray-50">
      <header className="border-b border-gray-200 bg-white">
        <div className="max-w-5xl mx-auto px-6 py-5 flex items-center justify-between">
          <div>
            <Link href="/admin" className="text-xs text-blue-600 hover:text-blue-800 font-medium">
              ← Back to Admin
            </Link>
            <h1 className="text-2xl font-bold text-gray-900 mt-1">Super Admins</h1>
            <p className="text-sm text-gray-500 mt-1">
              People who can create organizations and manage any org from the admin dashboard.
            </p>
          </div>
        </div>
      </header>

      <div className="max-w-5xl mx-auto px-6 py-8">
        <SuperAdminsClient
          rows={rows ?? []}
          currentUserEmail={user.email ?? ''}
        />
      </div>
    </main>
  )
}
