import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import NewOrgForm from '@/components/NewOrgForm'

export const dynamic = 'force-dynamic'

const ADMIN_EMAIL = 'nittonotakumi@gmail.com'

export default async function NewOrgPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user || user.email !== ADMIN_EMAIL) {
    redirect('/app')
  }

  return <NewOrgForm />
}
