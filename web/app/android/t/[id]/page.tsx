import Link from "next/link"
import { notFound, redirect } from "next/navigation"
import { createClient } from "@/utils/supabase/server"
import { CopyTranscript } from "@/components/android/CopyTranscript"

export const dynamic = "force-dynamic"

export const metadata = {
  title: "Transcript",
  robots: { index: false, follow: false },
}

export default async function TranscriptDetail({
  params,
}: {
  params: { id: string }
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect("/android")

  const { data: row } = await supabase
    .from("transcripts")
    .select("id, title, content, created_at, duration, word_count, language")
    .eq("id", params.id)
    .maybeSingle()

  if (!row) notFound()

  return (
    <main className="px-5 pt-6 pb-12">
      <div className="mb-4">
        <Link href="/android/library" className="text-sm text-blue-600 hover:underline">
          ← Library
        </Link>
      </div>

      <h1 className="text-2xl font-bold text-gray-900 mb-1">
        {row.title || "Untitled"}
      </h1>
      <p className="text-xs text-gray-500 mb-4">
        {new Date(row.created_at).toLocaleString()}
        {row.duration ? ` · ${Math.round(row.duration / 60)} min` : ""}
        {row.word_count ? ` · ${row.word_count} words` : ""}
      </p>

      <div className="mb-5">
        <CopyTranscript text={row.content || ""} />
      </div>

      <article className="prose prose-sm max-w-none whitespace-pre-wrap leading-relaxed text-gray-800">
        {row.content || "(empty)"}
      </article>
    </main>
  )
}
