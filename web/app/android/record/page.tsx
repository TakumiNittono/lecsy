import { redirect } from "next/navigation"
import { createClient } from "@/utils/supabase/server"
import { Recorder } from "@/components/android/Recorder"

export const dynamic = "force-dynamic"

export const metadata = {
  title: "Record",
  robots: { index: false, follow: false },
}

export default async function RecordPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect("/android")

  const { data: orgRow } = await supabase
    .from("organization_members")
    .select("organizations!inner(id)")
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(1)
    .maybeSingle()
  const orgId = (orgRow as any)?.organizations?.id as string | undefined
  if (!orgId) redirect("/android")

  return <Recorder orgId={orgId} />
}
