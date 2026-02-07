'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

interface ExamModeButtonProps {
  transcriptId: string
  isPro: boolean
}

interface ExamResponse {
  key_terms?: Array<{
    term: string
    definition: string
  }>
  questions?: Array<{
    question: string
    answer: string
  }>
  predictions?: string[]
  error?: string
}

export default function ExamModeButton({ transcriptId, isPro }: ExamModeButtonProps) {
  const [loading, setLoading] = useState(false)
  const [examData, setExamData] = useState<ExamResponse | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [showAnswers, setShowAnswers] = useState<Record<number, boolean>>({})
  const router = useRouter()

  if (!isPro) {
    return (
      <div className="p-4 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg border border-purple-200">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm font-semibold text-gray-900">Exam Prep Mode</span>
          <span className="px-2 py-1 bg-purple-600 text-white text-xs rounded-full font-semibold">Pro</span>
        </div>
        <p className="text-xs text-gray-600 mb-3">
          Upgrade to Pro to unlock exam preparation tools
        </p>
        <button
          onClick={() => router.push('/app#subscription')}
          className="w-full text-sm py-2 px-4 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition-colors"
        >
          Upgrade to Pro — $2.99/mo
        </button>
      </div>
    )
  }

  const handleGenerateExam = async () => {
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

      console.log('Making API request for exam prep with token:', session.access_token.substring(0, 20) + '...')

      const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/summarize`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          transcript_id: transcriptId,
          mode: 'exam',
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
        
        throw new Error(errorData.error || `Failed to generate exam prep (${response.status})`)
      }

      const data = await response.json()
      console.log('Exam prep generated successfully')
      setExamData(data.exam_mode || data)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'An error occurred'
      setError(errorMessage)
      console.error('Exam prep error:', err)
    } finally {
      setLoading(false)
    }
  }

  const toggleAnswer = (index: number) => {
    setShowAnswers(prev => ({
      ...prev,
      [index]: !prev[index]
    }))
  }

  return (
    <div className="space-y-4">
      {/* ボタン */}
      {!examData && (
        <button
          onClick={handleGenerateExam}
          disabled={loading}
          className="w-full px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-lg font-semibold hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
        >
          {loading ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Generating Exam Prep...
            </span>
          ) : (
            <span className="flex items-center justify-center gap-2">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Generate Exam Prep
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

      {/* 試験対策データ表示 */}
      {examData && (
        <div className="space-y-6 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          {/* ヘッダー */}
          <div className="flex items-center justify-between pb-4 border-b border-gray-200">
            <h2 className="text-xl font-bold text-gray-900 flex items-center gap-2">
              <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Exam Prep
            </h2>
            <button
              onClick={() => setExamData(null)}
              className="text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              Close
            </button>
          </div>

          {/* 重要用語 */}
          {examData.key_terms && examData.key_terms.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                Key Terms
              </h3>
              <div className="space-y-3">
                {examData.key_terms.map((item, index) => (
                  <div key={index} className="p-4 bg-purple-50 rounded-lg border border-purple-200">
                    <h4 className="font-semibold text-purple-900 mb-2">{item.term}</h4>
                    <p className="text-sm text-gray-700">{item.definition}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 練習問題 */}
          {examData.questions && examData.questions.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Practice Questions
              </h3>
              <div className="space-y-3">
                {examData.questions.map((item, index) => (
                  <div key={index} className="p-4 bg-gray-50 rounded-lg border border-gray-200">
                    <div className="flex items-start justify-between gap-3 mb-2">
                      <h4 className="font-semibold text-gray-900 flex-1">
                        <span className="text-purple-600 mr-2">Q{index + 1}.</span>
                        {item.question}
                      </h4>
                    </div>
                    <button
                      onClick={() => toggleAnswer(index)}
                      className="text-sm text-purple-600 hover:text-purple-700 font-medium transition-colors"
                    >
                      {showAnswers[index] ? 'Hide Answer' : 'Show Answer'}
                    </button>
                    {showAnswers[index] && (
                      <div className="mt-3 p-3 bg-white rounded border border-purple-200">
                        <p className="text-sm font-medium text-purple-900 mb-1">Answer:</p>
                        <p className="text-sm text-gray-700">{item.answer}</p>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 出題予想 */}
          {examData.predictions && examData.predictions.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
                Exam Predictions
              </h3>
              <ul className="space-y-2">
                {examData.predictions.map((prediction, index) => (
                  <li key={index} className="flex items-start gap-3 p-3 bg-yellow-50 rounded-lg border border-yellow-200">
                    <span className="flex-shrink-0 w-6 h-6 bg-yellow-500 text-white rounded-full flex items-center justify-center text-sm font-semibold">
                      !
                    </span>
                    <span className="text-gray-700 flex-1">{prediction}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* 再生成ボタン */}
          <div className="pt-4 border-t border-gray-200">
            <button
              onClick={handleGenerateExam}
              disabled={loading}
              className="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-lg font-medium hover:bg-gray-200 transition-colors disabled:opacity-50"
            >
              Regenerate Exam Prep
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
