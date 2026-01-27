"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"

interface EditTitleFormProps {
  transcriptId: string
  currentTitle: string | null
  defaultTitle: string
}

export default function EditTitleForm({ transcriptId, currentTitle, defaultTitle }: EditTitleFormProps) {
  const [isEditing, setIsEditing] = useState(false)
  const [title, setTitle] = useState(currentTitle || "")
  const [isSaving, setIsSaving] = useState(false)
  const router = useRouter()

  const displayTitle = currentTitle || defaultTitle

  const handleSave = async () => {
    const trimmedTitle = title.trim()
    if (trimmedTitle === currentTitle) {
      setIsEditing(false)
      return
    }

    setIsSaving(true)
    try {
      const response = await fetch(`/api/transcripts/${transcriptId}/title`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ title: trimmedTitle }),
      })

      if (!response.ok) {
        throw new Error("Failed to update title")
      }

      // ページをリフレッシュして最新のデータを取得
      router.refresh()
      setIsEditing(false)
    } catch (error) {
      console.error("Error updating title:", error)
      alert("Failed to update title. Please try again.")
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setTitle(currentTitle || "")
    setIsEditing(false)
  }

  if (isEditing) {
    return (
      <div className="mb-2">
        <div className="flex items-center gap-2">
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="flex-1 text-3xl font-bold text-gray-900 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            autoFocus
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                handleSave()
              } else if (e.key === "Escape") {
                handleCancel()
              }
            }}
          />
          <button
            onClick={handleSave}
            disabled={isSaving}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 text-sm"
          >
            {isSaving ? "Saving..." : "Save"}
          </button>
          <button
            onClick={handleCancel}
            disabled={isSaving}
            className="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors disabled:opacity-50 text-sm"
          >
            Cancel
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="mb-2 flex items-center gap-3">
      <h1 className="text-3xl font-bold text-gray-900 flex-1">
        {displayTitle}
      </h1>
      <button
        onClick={() => setIsEditing(true)}
        className="px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-50 rounded-lg transition-colors flex items-center gap-2"
        title="Edit title"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
          />
        </svg>
        Edit
      </button>
    </div>
  )
}
