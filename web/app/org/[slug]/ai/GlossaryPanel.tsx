'use client'

import { useState, useEffect } from 'react'
import type { OrgRole } from '@/utils/api/org-auth'

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

const ROLE_HIERARCHY: Record<OrgRole, number> = {
  owner: 4, admin: 3, teacher: 2, student: 1,
}

interface Transcript {
  id: string
  title: string
  language: string | null
  created_at: string
}

interface GlossaryTerm {
  id: string
  term: string
  definition: string
  language: string
  category: string | null
  created_at: string
}

export default function GlossaryPanel({
  slug,
  transcripts,
  glossaryCount,
  role,
}: {
  slug: string
  transcripts: Transcript[]
  glossaryCount: number
  role: OrgRole
}) {
  // Default to Browse when the org already has terms — directors want to see
  // what's already in the glossary, not be dropped into an empty Generate form.
  const [tab, setTab] = useState<'generate' | 'browse'>(glossaryCount > 0 ? 'browse' : 'generate')
  const canGenerate = ROLE_HIERARCHY[role] >= ROLE_HIERARCHY.teacher

  // Generate state
  const [selectedTranscript, setSelectedTranscript] = useState('')
  const [targetLanguage, setTargetLanguage] = useState('en')
  const [category, setCategory] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [generateResult, setGenerateResult] = useState<any>(null)

  // Browse state
  const [terms, setTerms] = useState<GlossaryTerm[]>([])
  const [browseLoading, setBrowseLoading] = useState(false)
  const [filterLanguage, setFilterLanguage] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [totalTerms, setTotalTerms] = useState(glossaryCount)

  const handleGenerate = async () => {
    if (!selectedTranscript) return
    setLoading(true)
    setError('')
    setGenerateResult(null)

    try {
      const res = await fetch(`/api/org/${slug}/ai/glossary`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          transcript_id: selectedTranscript,
          target_language: targetLanguage,
          category: category || undefined,
        }),
      })

      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error || 'Failed to generate glossary')
      }

      const data = await res.json()
      setGenerateResult(data)
      setTotalTerms((prev) => prev + (data.saved_count || 0))
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const fetchGlossary = async () => {
    setBrowseLoading(true)
    try {
      const params = new URLSearchParams()
      if (filterLanguage) params.set('language', filterLanguage)
      if (searchQuery) params.set('search', searchQuery)
      params.set('limit', '50')

      const res = await fetch(`/api/org/${slug}/ai/glossary?${params}`)
      if (!res.ok) throw new Error('Failed to fetch glossary')

      const data = await res.json()
      setTerms(data.terms)
      setTotalTerms(data.total)
    } catch {
      // silently fail
    } finally {
      setBrowseLoading(false)
    }
  }

  useEffect(() => {
    if (tab === 'browse') fetchGlossary()
  }, [tab, filterLanguage, searchQuery])

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200">
      <div className="px-6 py-4 border-b border-gray-200">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-emerald-100 rounded-lg flex items-center justify-center">
            <svg className="w-5 h-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
          </div>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Organization Glossary</h2>
            <p className="text-sm text-gray-500">{totalTerms} terms in your glossary</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200">
        <button
          onClick={() => setTab('generate')}
          className={`flex-1 py-2.5 text-sm font-medium text-center transition-colors ${
            tab === 'generate'
              ? 'text-emerald-700 border-b-2 border-emerald-600'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          Generate
        </button>
        <button
          onClick={() => setTab('browse')}
          className={`flex-1 py-2.5 text-sm font-medium text-center transition-colors ${
            tab === 'browse'
              ? 'text-emerald-700 border-b-2 border-emerald-600'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          Browse ({totalTerms})
        </button>
      </div>

      <div className="p-6">
        {tab === 'generate' ? (
          <div className="space-y-4">
            {!canGenerate ? (
              <div className="p-4 bg-amber-50 text-amber-700 text-sm rounded-lg">
                Glossary generation requires Teacher role or above.
              </div>
            ) : (
              <>
                {/* Transcript Select */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Select Transcript</label>
                  <select
                    value={selectedTranscript}
                    onChange={(e) => setSelectedTranscript(e.target.value)}
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
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
                  <label className="block text-sm font-medium text-gray-700 mb-1">Definition Language</label>
                  <select
                    value={targetLanguage}
                    onChange={(e) => setTargetLanguage(e.target.value)}
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  >
                    {LANGUAGES.map((l) => (
                      <option key={l.code} value={l.code}>{l.name}</option>
                    ))}
                  </select>
                </div>

                {/* Category (optional) */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Category <span className="text-gray-400">(optional)</span>
                  </label>
                  <input
                    type="text"
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    placeholder="e.g. grammar, business, medical"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  />
                </div>

                {/* Generate Button */}
                <button
                  onClick={handleGenerate}
                  disabled={!selectedTranscript || loading}
                  className="w-full py-2.5 px-4 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {loading ? 'Extracting Terms...' : 'Generate Glossary from Transcript'}
                </button>

                {error && (
                  <div className="p-3 bg-red-50 text-red-700 text-sm rounded-lg">{error}</div>
                )}

                {/* Generate Result */}
                {generateResult && (
                  <div className="space-y-3 pt-2">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium text-gray-900">
                        {generateResult.total_terms_found || generateResult.terms?.length || 0} terms extracted
                      </span>
                      {generateResult.saved_count > 0 && (
                        <span className="text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">
                          {generateResult.saved_count} saved to glossary
                        </span>
                      )}
                    </div>
                    {generateResult.lecture_topic && (
                      <p className="text-xs text-gray-500">Topic: {generateResult.lecture_topic}</p>
                    )}
                    <div className="space-y-2 max-h-80 overflow-y-auto">
                      {generateResult.terms?.map((term: any, i: number) => (
                        <div key={i} className="bg-gray-50 rounded-lg p-3">
                          <div className="flex items-start justify-between gap-2">
                            <span className="text-sm font-semibold text-gray-900">{term.term}</span>
                            {term.difficulty && (
                              <span className={`text-xs px-1.5 py-0.5 rounded-full ${
                                term.difficulty === 'beginner' ? 'bg-green-100 text-green-700' :
                                term.difficulty === 'intermediate' ? 'bg-yellow-100 text-yellow-700' :
                                'bg-red-100 text-red-700'
                              }`}>
                                {term.difficulty}
                              </span>
                            )}
                          </div>
                          <p className="text-sm text-gray-600 mt-1">{term.definition}</p>
                          {term.usage_example && (
                            <p className="text-xs text-gray-400 mt-1 italic">&quot;{term.usage_example}&quot;</p>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        ) : (
          /* Browse Tab */
          <div className="space-y-4">
            {/* Filters */}
            <div className="flex gap-3">
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search terms..."
                className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <select
                value={filterLanguage}
                onChange={(e) => setFilterLanguage(e.target.value)}
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >
                <option value="">All Languages</option>
                {LANGUAGES.map((l) => (
                  <option key={l.code} value={l.code}>{l.name}</option>
                ))}
              </select>
            </div>

            {/* Terms List */}
            {browseLoading ? (
              <div className="text-center py-8 text-sm text-gray-400">Loading...</div>
            ) : terms.length > 0 ? (
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {terms.map((term) => (
                  <div key={term.id} className="bg-gray-50 rounded-lg p-3">
                    <div className="flex items-start justify-between gap-2">
                      <span className="text-sm font-semibold text-gray-900">{term.term}</span>
                      <div className="flex gap-1.5">
                        <span className="text-xs px-1.5 py-0.5 rounded-full bg-gray-100 text-gray-600 uppercase">
                          {term.language}
                        </span>
                        {term.category && (
                          <span className="text-xs px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-600">
                            {term.category}
                          </span>
                        )}
                      </div>
                    </div>
                    <p className="text-sm text-gray-600 mt-1">{term.definition}</p>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8">
                <svg className="w-10 h-10 text-gray-300 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                <p className="text-sm text-gray-500">No terms yet</p>
                <p className="text-xs text-gray-400 mt-1">Generate glossary terms from transcripts to get started</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
