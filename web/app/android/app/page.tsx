import Link from "next/link"
import { redirect } from "next/navigation"
import { createClient } from "@/utils/supabase/server"

export const dynamic = "force-dynamic"

export const metadata = {
  title: "Home",
  robots: { index: false, follow: false },
}

export default async function AndroidHome() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect("/android")

  const { data: orgRow } = await supabase
    .from("organization_members")
    .select("organizations!inner(id, name, slug, logo_url)")
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(1)
    .maybeSingle()
  const org = (orgRow as any)?.organizations as
    | { id: string; name: string; slug: string; logo_url: string | null }
    | undefined

  if (!org) redirect("/android")

  const { data: recent } = await supabase
    .from("transcripts")
    .select("id, title, created_at, duration, word_count")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(5)

  return (
    <main className="px-5 pt-8">
      <header className="flex items-center gap-3 mb-8">
        {org.logo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={org.logo_url} alt={org.name} className="w-10 h-10 rounded-lg object-cover" />
        ) : (
          <div className="w-10 h-10 rounded-lg bg-blue-600" />
        )}
        <div>
          <p className="text-xs text-gray-500">Signed in to</p>
          <p className="font-semibold text-gray-900 text-sm">{org.name}</p>
        </div>
      </header>

      <div className="flex flex-col items-center pt-6 pb-12">
        <Link
          href="/android/record"
          className="w-44 h-44 rounded-full bg-red-600 text-white flex flex-col items-center justify-center shadow-xl shadow-red-600/30 active:scale-95 transition-transform"
          aria-label="Start recording"
        >
          <svg className="w-16 h-16 mb-1" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 14a3 3 0 003-3V6a3 3 0 10-6 0v5a3 3 0 003 3z" />
            <path d="M19 11a1 1 0 10-2 0 5 5 0 01-10 0 1 1 0 10-2 0 7 7 0 006 6.93V20H8a1 1 0 100 2h8a1 1 0 100-2h-3v-2.07A7 7 0 0019 11z" />
          </svg>
          <span className="font-semibold text-lg">Record</span>
        </Link>
        <p className="mt-4 text-xs text-gray-500">Tap to start live captions</p>
      </div>

      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold text-gray-900 text-base">Recent</h2>
          <Link href="/android/library" className="text-sm text-blue-600 hover:underline">
            See all
          </Link>
        </div>
        {!recent || recent.length === 0 ? (
          <div className="rounded-xl border border-dashed border-gray-300 p-6 text-center text-sm text-gray-500">
            No recordings yet.
          </div>
        ) : (
          <ul className="space-y-2">
            {recent.map((r: any) => (
              <li key={r.id}>
                <Link
                  href={`/android/t/${r.id}`}
                  className="block rounded-xl border border-gray-200 p-3 hover:bg-gray-50"
                >
                  <p className="font-medium text-gray-900 text-sm truncate">
                    {r.title || "Untitled"}
                  </p>
                  <p className="text-xs text-gray-500 mt-0.5">
                    {new Date(r.created_at).toLocaleString()}
                    {r.duration ? ` · ${Math.round(r.duration / 60)} min` : ""}
                    {r.word_count ? ` · ${r.word_count} words` : ""}
                  </p>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  )
}
