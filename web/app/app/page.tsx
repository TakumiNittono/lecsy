import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export default async function AppPage() {
  const supabase = createClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/login')
  }

  // 講義一覧を取得
  const { data: transcripts, error: transcriptsError } = await supabase
    .from('transcripts')
    .select('id, title, content, created_at, updated_at, duration, word_count, language')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  // エラーログ（開発環境のみ）
  if (transcriptsError) {
    console.error('Error fetching transcripts:', transcriptsError)
  }
  
  // デバッグログ（開発環境のみ）
  if (process.env.NODE_ENV === 'development') {
    console.log('Transcripts fetched:', transcripts?.length || 0)
    console.log('Sample transcript:', transcripts?.[0])
  }

  const handleSignOut = async () => {
    'use server'
    const supabase = createClient()
    await supabase.auth.signOut()
    redirect('/login')
  }

  // 統計情報を計算
  const totalLectures = transcripts?.length || 0
  const totalDuration = transcripts?.reduce((sum, t) => {
    const duration = t.duration ? Number(t.duration) : 0
    return sum + duration
  }, 0) || 0
  const totalHours = Math.floor(totalDuration / 3600)
  const totalMinutes = Math.floor((totalDuration % 3600) / 60)

  return (
    <main className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <Link href="/" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
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
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Welcome back!</h1>
          <p className="text-gray-600">Manage your lectures and transcripts</p>
        </div>

        {/* Dashboard Cards */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Total Lectures</h2>
              <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                </svg>
              </div>
            </div>
            <p className="text-3xl font-bold text-gray-900">{totalLectures}</p>
            <p className="text-sm text-gray-500 mt-2">Recorded lectures</p>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Total Time</h2>
              <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
            </div>
            <p className="text-3xl font-bold text-gray-900">
              {totalHours > 0 ? `${totalHours}h ` : ''}{totalMinutes}m
            </p>
            <p className="text-sm text-gray-500 mt-2">Recorded time</p>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Subscription</h2>
              <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                </svg>
              </div>
            </div>
            <p className="text-lg font-semibold text-gray-900">Free</p>
            <p className="text-sm text-gray-500 mt-2">Current plan</p>
          </div>
        </div>

        {/* Lectures List */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-gray-900">Your Lectures</h2>
            {/* New Lecture ボタンはiOSアプリから録音するため、Webでは非表示 */}
          </div>

          {transcriptsError ? (
            <div className="text-center py-12">
              <p className="text-red-600 text-lg mb-2">Error loading lectures</p>
              <p className="text-gray-500 text-sm">{transcriptsError.message}</p>
            </div>
          ) : transcripts && transcripts.length > 0 ? (
            <div className="space-y-4">
              {transcripts.map((transcript) => {
                const date = new Date(transcript.created_at)
                const formattedDate = date.toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric',
                })
                const formattedTime = date.toLocaleTimeString('en-US', {
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
                const preview = transcript.content
                  ? transcript.content.substring(0, 150) + (transcript.content.length > 150 ? '...' : '')
                  : 'No content'

                return (
                  <Link
                    key={transcript.id}
                    href={`/app/t/${transcript.id}`}
                    className="block p-6 border border-gray-200 rounded-lg hover:border-blue-300 hover:shadow-md transition-all"
                  >
                    <div className="flex items-start justify-between mb-3">
                      <h3 className="text-lg font-semibold text-gray-900 line-clamp-1">
                        {transcript.title || `Lecture ${formattedDate}`}
                      </h3>
                      <span className="text-sm text-gray-500 ml-4 flex-shrink-0">
                        {formattedDate} {formattedTime}
                      </span>
                    </div>
                    <div className="flex items-center gap-4 mb-3 text-sm text-gray-500">
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
                    </div>
                    <p className="text-gray-600 text-sm line-clamp-2">{preview}</p>
                  </Link>
                )
              })}
            </div>
          ) : (
            <div className="text-center py-12">
              <svg className="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
              </svg>
              <p className="text-gray-500 text-lg mb-2">No lectures yet</p>
              <p className="text-gray-400 text-sm">Record your first lecture using the lecsy iPhone app</p>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
