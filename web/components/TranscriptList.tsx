"use client"

import { useState, useMemo } from "react"
import Link from "next/link"
import SearchBar from "./SearchBar"

interface Transcript {
  id: string
  title: string | null
  content: string
  created_at: string
  updated_at: string
  duration: number | null
  word_count: number | null
  language: string | null
}

interface TranscriptListProps {
  transcripts: Transcript[]
}

export default function TranscriptList({ transcripts }: TranscriptListProps) {
  const [searchQuery, setSearchQuery] = useState("")

  // 検索フィルタリング
  const filteredTranscripts = useMemo(() => {
    if (!searchQuery.trim()) {
      return transcripts
    }

    const query = searchQuery.toLowerCase()
    return transcripts.filter((transcript) => {
      const title = (transcript.title || "").toLowerCase()
      const content = transcript.content.toLowerCase()
      return title.includes(query) || content.includes(query)
    })
  }, [transcripts, searchQuery])

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-gray-900">Your Lectures</h2>
      </div>

      {/* Search Bar */}
      <div className="mb-6">
        <SearchBar
          onSearch={setSearchQuery}
          placeholder="Search by title or content..."
        />
      </div>

      {/* Results Count */}
      {searchQuery && (
        <div className="mb-4 text-sm text-gray-600">
          {filteredTranscripts.length === 0 ? (
            <span>No lectures found</span>
          ) : (
            <span>
              Found {filteredTranscripts.length} lecture{filteredTranscripts.length !== 1 ? "s" : ""}
            </span>
          )}
        </div>
      )}

      {/* Transcripts List */}
      {filteredTranscripts.length > 0 ? (
        <div className="space-y-4">
          {filteredTranscripts.map((transcript) => {
            const date = new Date(transcript.created_at)
            const formattedDate = date.toLocaleDateString("en-US", {
              year: "numeric",
              month: "short",
              day: "numeric",
            })
            const formattedTime = date.toLocaleTimeString("en-US", {
              hour: "2-digit",
              minute: "2-digit",
            })
            const duration = transcript.duration
              ? (() => {
                  const durationNum = Number(transcript.duration)
                  const minutes = Math.floor(durationNum / 60)
                  const seconds = Math.floor(durationNum % 60)
                  return `${minutes}m ${seconds}s`
                })()
              : "N/A"
            const preview = transcript.content
              ? transcript.content.substring(0, 150) + (transcript.content.length > 150 ? "..." : "")
              : "No content"

            // 検索クエリが含まれている場合、ハイライト表示
            const highlightText = (text: string, query: string) => {
              if (!query.trim()) return text
              const parts = text.split(new RegExp(`(${query})`, "gi"))
              return (
                <>
                  {parts.map((part, index) =>
                    part.toLowerCase() === query.toLowerCase() ? (
                      <mark key={index} className="bg-yellow-200 px-1 rounded">
                        {part}
                      </mark>
                    ) : (
                      part
                    )
                  )}
                </>
              )
            }

            return (
              <Link
                key={transcript.id}
                href={`/app/t/${transcript.id}`}
                className="block p-6 border border-gray-200 rounded-lg hover:border-blue-300 hover:shadow-md transition-all"
              >
                <div className="flex items-start justify-between mb-3">
                  <h3 className="text-lg font-semibold text-gray-900 line-clamp-1">
                    {searchQuery
                      ? highlightText(transcript.title || `Lecture ${formattedDate}`, searchQuery)
                      : transcript.title || `Lecture ${formattedDate}`}
                  </h3>
                  <span className="text-sm text-gray-500 ml-4 flex-shrink-0">
                    {formattedDate} {formattedTime}
                  </span>
                </div>
                <div className="flex items-center gap-4 mb-3 text-sm text-gray-500">
                  <span className="flex items-center gap-1">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    {duration}
                  </span>
                  {transcript.word_count && (
                    <span className="flex items-center gap-1">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                        />
                      </svg>
                      {transcript.word_count.toLocaleString()} words
                    </span>
                  )}
                </div>
                <p className="text-gray-600 text-sm line-clamp-2">
                  {searchQuery ? highlightText(preview, searchQuery) : preview}
                </p>
              </Link>
            )
          })}
        </div>
      ) : (
        <div className="text-center py-12">
          <svg
            className="w-16 h-16 text-gray-400 mx-auto mb-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
            />
          </svg>
          <p className="text-gray-500 text-lg mb-2">
            {searchQuery ? "No lectures found" : "No lectures yet"}
          </p>
          <p className="text-gray-400 text-sm">
            {searchQuery
              ? "Try a different search term"
              : "Record your first lecture using the lecsy iPhone app"}
          </p>
        </div>
      )}
    </div>
  )
}
