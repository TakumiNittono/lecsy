import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import AcceptInvite from '@/components/AcceptInvite'

export const dynamic = 'force-dynamic'

export default async function InvitePage({
  params,
}: {
  params: { token: string }
}) {
  const supabase = createClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect(`/login?next=/invite/${params.token}`)
  }

  // Query the invite by token
  const { data: invite, error } = await supabase
    .from('organization_invites')
    .select('id, token, role, expires_at, accepted_at, org_id, organizations(name, slug)')
    .eq('token', params.token)
    .single()

  if (error || !invite) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8 max-w-md w-full text-center">
          <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <h1 className="text-xl font-bold text-gray-900 mb-2">Invalid Invitation</h1>
          <p className="text-gray-500">This invitation link is invalid or does not exist.</p>
        </div>
      </div>
    )
  }

  // Check if already accepted
  if (invite.accepted_at) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8 max-w-md w-full text-center">
          <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h1 className="text-xl font-bold text-gray-900 mb-2">Already Accepted</h1>
          <p className="text-gray-500">This invitation has already been accepted.</p>
        </div>
      </div>
    )
  }

  // Check if expired
  if (new Date(invite.expires_at) < new Date()) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8 max-w-md w-full text-center">
          <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h1 className="text-xl font-bold text-gray-900 mb-2">Invitation Expired</h1>
          <p className="text-gray-500">This invitation has expired. Please ask the organization admin for a new invite.</p>
        </div>
      </div>
    )
  }

  const orgData = invite.organizations as any
  const orgName = orgData?.name || 'Unknown Organization'

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <AcceptInvite
        token={params.token}
        orgName={orgName}
        role={invite.role}
      />
    </div>
  )
}
