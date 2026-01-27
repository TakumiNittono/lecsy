import { createClient } from '@/utils/supabase/server'
import { redirect, notFound } from 'next/navigation'
import Link from 'next/link'
import CopyButton from '@/components/CopyButton'
import EditTitleForm from '@/components/EditTitleForm'

export default async function TranscriptDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  try {
    const { id } = await params
    
    // IDのバリデーション
    if (!id || typeof id !== 'string') {
      notFound()
    }

    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      redirect('/login')
    }

    // 講義詳細を取得
    const { data: transcriptRaw, error: transcriptError } = await supabase
      .from('transcripts')
      .select('id, title, content, created_at, updated_at, duration, word_count, language')
      .eq('id', id)
      .eq('user_id', user.id)
      .single()

    // エラーハンドリングを改善
    if (transcriptError) {
      console.error('Error fetching transcript:', {
        code: transcriptError.code,
        message: transcriptError.message,
        details: transcriptError.details,
        hint: transcriptError.hint,
        id,
        userId: user.id
      })
      // PGRST116エラー（レコードが見つからない）の場合のみnotFoundを呼ぶ
      if (transcriptError.code === 'PGRST116') {
        notFound()
      }
      // その他のエラーの場合はエラーページを表示
      throw new Error(`Failed to load transcript: ${transcriptError.message || 'Unknown error'}`)
    }

    if (!transcriptRaw) {
      notFound()
    }

    // durationを数値に変換
    const transcript = {
      ...transcriptRaw,
      duration: transcriptRaw.duration != null 
        ? (typeof transcriptRaw.duration === 'string' 
            ? parseFloat(transcriptRaw.duration) 
            : Number(transcriptRaw.duration))
        : null
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
        .eq('id', id)
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
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50 no-print">
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
          className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6 transition-colors no-print"
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
          <div className="flex items-center gap-3 pt-4 border-t border-gray-200 flex-wrap no-print">
            {transcript.content && (
              <CopyButton content={transcript.content} />
            )}
            <button
              onClick={() => window.print()}
              className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors font-medium flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              Print
            </button>
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
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">Transcript</h2>
            <div className="text-sm text-gray-500">
              {transcript.content ? `${transcript.content.length.toLocaleString()} characters` : 'No content'}
            </div>
          </div>
          
          {transcript.content ? (
            <div className="relative">
              {/* テキストコンテンツ */}
              <div 
                className="prose prose-lg max-w-none 
                  text-gray-900 
                  leading-7 
                  font-normal
                  whitespace-pre-wrap 
                  break-words
                  selection:bg-blue-200
                  selection:text-gray-900
                  focus:outline-none
                  p-4
                  bg-gray-50
                  rounded-lg
                  border border-gray-200
                  min-h-[200px]
                  max-h-[70vh]
                  overflow-y-auto
                  scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100"
                style={{
                  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
                  fontSize: '16px',
                  lineHeight: '1.75',
                }}
              >
                {transcript.content}
              </div>
              
              {/* スクロールインジケーター */}
              <div className="mt-2 text-xs text-gray-400 text-center">
                Scroll to read full transcript
              </div>
            </div>
          ) : (
            <div className="text-center py-12 text-gray-500">
              <svg className="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <p>No content available</p>
            </div>
          )}
        </div>
      </div>
      </main>
    )
  } catch (error) {
    console.error('TranscriptDetailPage error:', error)
    // エラーを再スローしてerror.tsxで処理
    throw error
  }
}
