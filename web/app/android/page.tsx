import type { Metadata } from "next"
import { Suspense } from "react"
import Link from "next/link"
import { redirect } from "next/navigation"
import { createClient } from "@/utils/supabase/server"
import { InviteCodeForm } from "@/components/android/InviteCodeForm"
import { InstallPrompt } from "@/components/android/InstallPrompt"

export const dynamic = "force-dynamic"

export const metadata: Metadata = {
  title: "Join your class on Lecsy",
  description: "Enter your invite code to start recording lectures.",
  robots: { index: false, follow: false },
}

export default async function AndroidEntry() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (user) {
    const { data: membership } = await supabase
      .from("organization_members")
      .select("id")
      .eq("user_id", user.id)
      .eq("status", "active")
      .limit(1)
      .maybeSingle()
    if (membership) redirect("/android/app")
  }

  return (
    <main className="min-h-screen bg-gradient-to-b from-blue-50 via-white to-white">
      <div className="max-w-md mx-auto px-5 pt-12 pb-24">
        <div className="text-center mb-8">
          <div className="inline-flex w-20 h-20 mb-5 rounded-2xl bg-blue-600 text-white items-center justify-center shadow-sm">
            <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 14l9-5-9-5-9 5 9 5z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
            </svg>
          </div>
          <h1 className="text-3xl font-bold tracking-tight text-gray-900 mb-2">
            Welcome to Lecsy
          </h1>
          <p className="text-gray-600">
            Live captions and transcripts for your lectures.
          </p>
        </div>

        <Suspense fallback={<div className="h-48 rounded-2xl bg-gray-100 animate-pulse" />}>
          <InviteCodeForm />
        </Suspense>

        <div className="mt-6">
          <InstallPrompt />
        </div>

        <div className="mt-10 text-center text-sm text-gray-500">
          Don&apos;t have a code?{" "}
          <Link href="/support" className="text-blue-600 hover:underline">
            Ask your teacher
          </Link>
        </div>

        <div className="mt-8 p-5 rounded-xl bg-gray-50 border border-gray-200 text-xs text-gray-600 leading-relaxed">
          <p className="font-semibold text-gray-800 mb-1">Your privacy</p>
          <p>
            Audio is processed for transcription and is never stored by Lecsy. Transcripts
            are scoped to your school. See our{" "}
            <Link href="/privacy" className="text-blue-600 hover:underline">Privacy Policy</Link>.
          </p>
        </div>
      </div>
    </main>
  )
}
