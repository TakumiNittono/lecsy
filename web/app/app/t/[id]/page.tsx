import { createClient } from '@/utils/supabase/server'
import { redirect, notFound } from 'next/navigation'
import Link from 'next/link'
import CopyButton from '@/components/CopyButton'
import EditTitleForm from '@/components/EditTitleForm'
import PrintButton from '@/components/PrintButton'
import DeleteForm from '@/components/DeleteForm'
import AISummaryButton from '@/components/AISummaryButton'
import ExamModeButton from '@/components/ExamModeButton'
import { sanitizeText } from '@/utils/sanitize'

// 動的レンダリングを強制（cookiesを使用するため）
export const dynamic = 'force-dynamic'

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

    // ホワイトリストチェック
    const whitelistEmails = process.env.WHITELIST_EMAILS || ''
    const whitelistedUsers = whitelistEmails.split(',').map(email => email.trim())
    const isWhitelisted = !!(user.email && whitelistedUsers.includes(user.email))

    // Pro状態を取得
    const { data: subscription } = await supabase
      .from('subscriptions')
      .select('status')
      .eq('user_id', user.id)
      .single()

    // ホワイトリストユーザーは自動的にProとして扱う
    const isPro = isWhitelisted || subscription?.status === 'active'

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
            <PrintButton />
            <DeleteForm transcriptId={transcript.id} />
          </div>

          {/* Pro Features - AI Summary & Exam Prep */}
          <div className="mt-4 pt-4 border-t border-gray-200 space-y-4 no-print">
            <AISummaryButton
              transcriptId={transcript.id}
              isPro={isPro}
            />
            <ExamModeButton
              transcriptId={transcript.id}
              isPro={isPro}
            />
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
                {sanitizeText(transcript.content)}
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

      {/* Footer */}
      <footer className="border-t border-gray-200 py-6 bg-white mt-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-center text-gray-600 text-sm">
            <div className="mb-4 md:mb-0">© 2026 lecsy. All rights reserved.</div>
            <div className="flex gap-6">
              <Link href="/privacy" className="hover:text-gray-900 transition-colors">Privacy Policy</Link>
              <Link href="/terms" className="hover:text-gray-900 transition-colors">Terms of Service</Link>
            </div>
          </div>
        </div>
      </footer>
      </main>
    )
  } catch (error) {
    // 詳細なエラーログを出力
    console.error('TranscriptDetailPage error:', {
      error,
      message: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
    })
    
    // エラーを再スローしてerror.tsxで処理
    throw error
  }
}
