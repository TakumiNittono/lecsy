'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

interface AISummaryButtonProps {
  transcriptId: string
  isPro: boolean
}

interface SummaryResponse {
  summary?: string
  key_points?: string[]
  sections?: Array<{
    heading: string
    content: string
  }>
  error?: string
}

const LANGUAGES = [
  { code: 'ja', label: '日本語', name: 'Japanese' },
  { code: 'en', label: 'English', name: 'English' },
  { code: 'es', label: 'Español', name: 'Spanish' },
  { code: 'zh', label: '中文', name: 'Chinese' },
  { code: 'ko', label: '한국어', name: 'Korean' },
  { code: 'fr', label: 'Français', name: 'French' },
  { code: 'de', label: 'Deutsch', name: 'German' },
]

export default function AISummaryButton({ transcriptId, isPro }: AISummaryButtonProps) {
  const [loading, setLoading] = useState(false)
  const [summary, setSummary] = useState<SummaryResponse | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [selectedLanguage, setSelectedLanguage] = useState('ja')
  const router = useRouter()

  if (!isPro) {
    return (
      <div className="p-4 bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg border border-blue-200">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm font-semibold text-gray-900">AI Summary</span>
          <span className="px-2 py-1 bg-blue-600 text-white text-xs rounded-full font-semibold">Pro</span>
        </div>
        <p className="text-xs text-gray-600 mb-3">
          Upgrade to Pro to unlock AI-powered summaries
        </p>
        <button
          onClick={() => router.push('/app#subscription')}
          className="w-full text-sm py-2 px-4 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
        >
          Upgrade to Pro — $2.99/mo
        </button>
      </div>
    )
  }

  const handleSummarize = async () => {
    setLoading(true)
    setError(null)
    
    try {
      // Supabase clientをインポートして認証トークンを取得
      const { createClient } = await import('@/utils/supabase/client')
      const supabase = createClient()
      
      // セッションを取得
      const { data: { session }, error: sessionError } = await supabase.auth.getSession()
      
      if (sessionError || !session) {
        console.error('Session error:', sessionError)
        throw new Error('Not authenticated. Please log in again.')
      }

      console.log('Making API request with token:', session.access_token.substring(0, 20) + '...')

      const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/summarize`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          transcript_id: transcriptId,
          mode: 'summary',
          output_language: selectedLanguage,
        }),
      })

      console.log('API response status:', response.status)

      if (!response.ok) {
        const errorText = await response.text()
        console.error('API error response:', errorText)
        
        let errorData
        try {
          errorData = JSON.parse(errorText)
        } catch {
          throw new Error(`Server error (${response.status}): ${errorText}`)
        }
        
        throw new Error(errorData.error || `Failed to generate summary (${response.status})`)
      }

      const data = await response.json()
      console.log('Summary generated successfully')
      setSummary(data)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'An error occurred'
      setError(errorMessage)
      console.error('Summary error:', err)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-4">
      {/* 言語選択UI */}
      {!summary && (
        <div className="p-4 bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg border border-blue-200">
          <label className="block text-sm font-semibold text-gray-900 mb-3">
            Summary Language / サマリーの言語
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4">
            {LANGUAGES.map((lang) => (
              <button
                key={lang.code}
                onClick={() => setSelectedLanguage(lang.code)}
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-all ${
                  selectedLanguage === lang.code
                    ? 'bg-blue-600 text-white shadow-md'
                    : 'bg-white text-gray-700 hover:bg-blue-100 border border-gray-300'
                }`}
              >
                {lang.label}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* ボタン */}
      {!summary && (
        <button
          onClick={handleSummarize}
          disabled={loading}
          className="w-full px-6 py-3 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg font-semibold hover:from-blue-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
        >
          {loading ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Generating AI Summary...
            </span>
          ) : (
            <span className="flex items-center justify-center gap-2">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              Generate AI Summary
            </span>
          )}
        </button>
      )}

      {/* エラー表示 */}
      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-start gap-3">
            <svg className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div>
              <p className="text-sm font-medium text-red-800">Error</p>
              <p className="text-sm text-red-700 mt-1">{error}</p>
            </div>
          </div>
        </div>
      )}

      {/* 要約結果表示 */}
      {summary && (
        <div className="space-y-6 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          {/* ヘッダー */}
          <div className="flex items-center justify-between pb-4 border-b border-gray-200">
            <h2 className="text-xl font-bold text-gray-900 flex items-center gap-2">
              <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              AI Summary
            </h2>
            <button
              onClick={() => setSummary(null)}
              className="text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              Close
            </button>
          </div>

          {/* 要約 */}
          {summary.summary && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3">Summary</h3>
              <p className="text-gray-700 leading-relaxed">{summary.summary}</p>
            </div>
          )}

          {/* キーポイント */}
          {summary.key_points && summary.key_points.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3">Key Points</h3>
              <ul className="space-y-2">
                {summary.key_points.map((point, index) => (
                  <li key={index} className="flex items-start gap-3">
                    <span className="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-semibold">
                      {index + 1}
                    </span>
                    <span className="text-gray-700 flex-1">{point}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* セクション */}
          {summary.sections && summary.sections.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3">Sections</h3>
              <div className="space-y-3">
                {summary.sections.map((section, index) => (
                  <div key={index} className="p-4 bg-gray-50 rounded-lg border border-gray-200">
                    <h4 className="font-semibold text-gray-900 mb-2">{section.heading}</h4>
                    <p className="text-sm text-gray-700">{section.content}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 再生成ボタン */}
          <div className="pt-4 border-t border-gray-200">
            <button
              onClick={handleSummarize}
              disabled={loading}
              className="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-lg font-medium hover:bg-gray-200 transition-colors disabled:opacity-50"
            >
              Regenerate Summary
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
