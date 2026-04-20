import { createClient } from '@/utils/supabase/server'
import { getOrgMembership, getUserOrganizations } from '@/utils/api/org-auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import OrgSidebar from '@/components/OrgSidebar'
import OrgSwitcher from '@/components/OrgSwitcher'

export const dynamic = 'force-dynamic'

export default async function OrgLayout({
  children,
  params,
}: {
  children: React.ReactNode
  params: { slug: string }
}) {
  // 並列実行: getOrgMembership と getUserOrganizations は独立しているので
  // 直列 await だと Supabase への往復が2回シリアルになる (+300〜400ms)。
  // どちらも cache() 済みなので getCachedUser の呼び出しは1回に合算される。
  const [membership, userOrgs] = await Promise.all([
    getOrgMembership(params.slug),
    getUserOrganizations(),
  ])

  if (!membership || membership.role === 'student') {
    redirect('/app')
  }

  const handleSignOut = async () => {
    'use server'
    const supabase = createClient()
    await supabase.auth.signOut()
    redirect('/login')
  }

  return (
    <div className="min-h-screen bg-gray-50" data-dashboard>
      {/* Header */}
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center gap-3">
            <Link href="/app" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
              lecsy
            </Link>
            {membership.org.logo_url ? (
              <>
                <span className="text-gray-200">/</span>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={membership.org.logo_url}
                  alt={`${membership.org.name} logo`}
                  className="h-7 w-auto max-w-[120px] object-contain"
                />
              </>
            ) : (
              <span className="text-gray-300">|</span>
            )}
            <OrgSwitcher currentSlug={params.slug} currentOrgName={membership.org.name} orgs={userOrgs} />
          </div>
          <div className="flex items-center gap-4">
            <span className="text-gray-700 text-sm">{membership.userEmail}</span>
            <form action={handleSignOut}>
              <button
                type="submit"
                className="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors font-medium"
              >
                Logout
              </button>
            </form>
          </div>
        </div>
      </header>

      {/* Body with sidebar */}
      <div className="flex">
        <OrgSidebar slug={params.slug} role={membership.role} />
        <main className="flex-1 min-w-0">
          {children}
        </main>
      </div>
    </div>
  )
}
