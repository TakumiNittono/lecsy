import { createClient } from '@/utils/supabase/server'
import { redirect, notFound } from 'next/navigation'
import Link from 'next/link'
import CopyButton from '@/components/CopyButton'
import EditTitleForm from '@/components/EditTitleForm'

export default async function TranscriptDetailPage({
  params,
}: {
  params: { id: string }
}) {
  const supabase = createClient()
  const { data: { user }, error: authError } = await supabase.auth.getUser()

  if (authError || !user) {
    redirect('/login')
  }

  // 講義詳細を取得
  const { data: transcript, error: transcriptError } = await supabase
    .from('transcripts')
    .select('id, title, content, created_at, updated_at, duration, word_count, language')
    .eq('id', params.id)
    .eq('user_id', user.id)
    .single()

  if (transcriptError || !transcript) {
    notFound()
  }

  const handleSignOut = async () => {
    'use server'
    const supabase = createClient()
    await supabase.auth.signOut()
    redirect('/login')
  }

  const handleDelete = async () => {
    'use server'
    const supabase = createClient()
    const { error } = await supabase
      .from('transcripts')
      .delete()
      .eq('id', params.id)
      .eq('user_id', user.id)
    
    if (!error) {
      redirect('/app')
    }
  }

  const date = new Date(transcript.created_at)
  const formattedDate = date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
  const duration = transcript.duration
    ? (() => {
        const durationNum = Number(transcript.duration)
        const minutes = Math.floor(durationNum / 60)
        const seconds = Math.floor(durationNum % 60)
        return `${minutes}m ${seconds}s`
      })()
    : 'N/A'

  return (
    <main className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <Link href="/app" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
            lecsy
          </Link>
          <div className="flex items-center gap-4">
            <span className="text-gray-700 text-sm">{user.email}</span>
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

      {/* Main Content */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Back Button */}
        <Link
          href="/app"
          className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6 transition-colors"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Back to Lectures
        </Link>

        {/* Transcript Header */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
          <div className="flex items-start justify-between mb-4">
            <div className="flex-1">
              <EditTitleForm
                transcriptId={transcript.id}
                currentTitle={transcript.title}
                defaultTitle={`Lecture ${formattedDate}`}
              />
              <div className="flex items-center gap-4 text-sm text-gray-500">
                <span>{formattedDate}</span>
                <span className="flex items-center gap-1">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  {duration}
                </span>
                {transcript.word_count && (
                  <span className="flex items-center gap-1">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    {transcript.word_count.toLocaleString()} words
                  </span>
                )}
                {transcript.language && (
                  <span className="px-2 py-1 bg-gray-100 rounded text-xs">
                    {transcript.language.toUpperCase()}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-3 pt-4 border-t border-gray-200">
            <CopyButton content={transcript.content} />
            <form action={handleDelete}>
              <button
                type="submit"
                className="px-4 py-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors font-medium"
                onClick={(e) => {
                  if (!confirm('Are you sure you want to delete this lecture?')) {
                    e.preventDefault()
                  }
                }}
              >
                Delete
              </button>
            </form>
          </div>
        </div>

        {/* Transcript Content */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="prose max-w-none">
            <div className="whitespace-pre-wrap text-gray-900 leading-relaxed">
              {transcript.content || 'No content available'}
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}
