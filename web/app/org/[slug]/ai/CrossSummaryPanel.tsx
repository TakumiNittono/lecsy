'use client'

import { useState } from 'react'

const LANGUAGES = [
  { code: 'ja', name: 'Japanese' },
  { code: 'en', name: 'English' },
  { code: 'es', name: 'Spanish' },
  { code: 'zh', name: 'Chinese' },
  { code: 'ko', name: 'Korean' },
  { code: 'fr', name: 'French' },
  { code: 'de', name: 'German' },
  { code: 'pt', name: 'Portuguese' },
  { code: 'it', name: 'Italian' },
  { code: 'ru', name: 'Russian' },
  { code: 'ar', name: 'Arabic' },
  { code: 'hi', name: 'Hindi' },
]

interface Transcript {
  id: string
  title: string
  language: string | null
  created_at: string
}

interface CrossSummaryResult {
  summary: string
  key_points: string[]
  sections: Array<{ heading: string; content: string }>
  source_language: string
  target_language: string
  key_terms_bilingual: Array<{ original: string; translated: string; context: string }>
}

export default function CrossSummaryPanel({
  slug,
  transcripts,
}: {
  slug: string
  transcripts: Transcript[]
}) {
  const [selectedTranscript, setSelectedTranscript] = useState('')
  const [targetLanguage, setTargetLanguage] = useState('ja')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [result, setResult] = useState<CrossSummaryResult | null>(null)

  const handleGenerate = async () => {
    if (!selectedTranscript) return
    setLoading(true)
    setError('')
    setResult(null)

    try {
      const res = await fetch(`/api/org/${slug}/ai/cross-summary`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          transcript_id: selectedTranscript,
          target_language: targetLanguage,
        }),
      })

      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error || 'Failed to generate summary')
      }

      const data = await res.json()
      setResult(data)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200">
      <div className="px-6 py-4 border-b border-gray-200">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center">
            <svg className="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
            </svg>
          </div>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Cross-Language Summary</h2>
            <p className="text-sm text-gray-500">Summarize a lecture in a different language</p>
          </div>
        </div>
      </div>

      <div className="p-6 space-y-4">
        {/* Transcript Select */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Select Transcript</label>
          <select
            value={selectedTranscript}
            onChange={(e) => setSelectedTranscript(e.target.value)}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="">Choose a transcript...</option>
            {transcripts.map((t) => (
              <option key={t.id} value={t.id}>
                {t.title || 'Untitled'} ({t.language || '?'}) - {new Date(t.created_at).toLocaleDateString()}
              </option>
            ))}
          </select>
        </div>

        {/* Target Language */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Output Language</label>
          <select
            value={targetLanguage}
            onChange={(e) => setTargetLanguage(e.target.value)}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            {LANGUAGES.map((l) => (
              <option key={l.code} value={l.code}>{l.name}</option>
            ))}
          </select>
        </div>

        {/* Generate Button */}
        <button
          onClick={handleGenerate}
          disabled={!selectedTranscript || loading}
          className="w-full py-2.5 px-4 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {loading ? 'Generating...' : 'Generate Cross-Language Summary'}
        </button>

        {error && (
          <div className="p-3 bg-red-50 text-red-700 text-sm rounded-lg">{error}</div>
        )}

        {/* Result */}
        {result && (
          <div className="space-y-4 pt-2">
            <div className="p-3 bg-indigo-50 rounded-lg text-xs text-indigo-700">
              {result.source_language} &rarr; {result.target_language}
            </div>

            {/* Summary */}
            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-1">Summary</h3>
              <p className="text-sm text-gray-700 leading-relaxed">{result.summary}</p>
            </div>

            {/* Key Points */}
            {result.key_points && result.key_points.length > 0 && (
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Key Points</h3>
                <ul className="list-disc list-inside text-sm text-gray-700 space-y-1">
                  {result.key_points.map((point, i) => (
                    <li key={i}>{point}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Sections */}
            {result.sections && result.sections.length > 0 && (
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-2">Sections</h3>
                <div className="space-y-3">
                  {result.sections.map((section, i) => (
                    <div key={i} className="border-l-2 border-indigo-200 pl-3">
                      <h4 className="text-sm font-medium text-gray-800">{section.heading}</h4>
                      <p className="text-sm text-gray-600 mt-0.5">{section.content}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Bilingual Terms */}
            {result.key_terms_bilingual && result.key_terms_bilingual.length > 0 && (
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-2">Key Terms (Bilingual)</h3>
                <div className="grid gap-2">
                  {result.key_terms_bilingual.map((term, i) => (
                    <div key={i} className="flex items-start gap-2 bg-gray-50 rounded-lg p-2.5 text-sm">
                      <span className="font-medium text-gray-900 whitespace-nowrap">{term.original}</span>
                      <span className="text-gray-400">&rarr;</span>
                      <span className="text-indigo-700 font-medium">{term.translated}</span>
                      {term.context && (
                        <span className="text-gray-400 text-xs ml-auto">({term.context})</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
