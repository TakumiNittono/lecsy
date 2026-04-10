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
  const membership = await getOrgMembership(params.slug)

  if (!membership || membership.role === 'student') {
    redirect('/app')
  }

  const userOrgs = await getUserOrganizations()

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
          <div className="flex items-center gap-4">
            <Link href="/app" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
              lecsy
            </Link>
            <span className="text-gray-300">|</span>
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
