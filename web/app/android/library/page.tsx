import Link from "next/link"
import { redirect } from "next/navigation"
import { createClient } from "@/utils/supabase/server"

export const dynamic = "force-dynamic"

export const metadata = {
  title: "Library",
  robots: { index: false, follow: false },
}

export default async function LibraryPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect("/android")

  const { data: rows } = await supabase
    .from("transcripts")
    .select("id, title, created_at, duration, word_count")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(100)

  return (
    <main className="px-5 pt-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Library</h1>
      {!rows || rows.length === 0 ? (
        <div className="rounded-xl border border-dashed border-gray-300 p-8 text-center">
          <p className="text-gray-500 text-sm mb-4">No recordings yet.</p>
          <Link
            href="/android/record"
            className="inline-block px-5 h-11 leading-[2.75rem] rounded-lg bg-blue-600 text-white font-semibold text-sm"
          >
            Record your first lecture
          </Link>
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((r: any) => (
            <li key={r.id}>
              <Link
                href={`/android/t/${r.id}`}
                className="block rounded-xl border border-gray-200 p-4 hover:bg-gray-50 active:bg-gray-100"
              >
                <p className="font-medium text-gray-900 truncate">
                  {r.title || "Untitled"}
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  {new Date(r.created_at).toLocaleString()}
                  {r.duration ? ` · ${Math.round(r.duration / 60)} min` : ""}
                  {r.word_count ? ` · ${r.word_count} words` : ""}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  )
}
