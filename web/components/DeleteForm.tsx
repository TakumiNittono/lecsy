'use client'

import { useRouter } from 'next/navigation'

interface DeleteFormProps {
  transcriptId: string
}

export default function DeleteForm({ transcriptId }: DeleteFormProps) {
  const router = useRouter()

  const handleDelete = async () => {
    if (!confirm('Are you sure you want to delete this lecture?')) {
      return
    }

    try {
      const response = await fetch(`/api/transcripts/${transcriptId}`, {
        method: 'DELETE',
      })

      if (!response.ok) {
        throw new Error('Failed to delete lecture')
      }

      // 削除成功後、一覧ページにリダイレクト
      router.push('/app')
    } catch (error) {
      console.error('Error deleting lecture:', error)
      alert('Failed to delete lecture. Please try again.')
    }
  }

  return (
    <button
      onClick={handleDelete}
      className="px-4 py-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors font-medium"
    >
      Delete
    </button>
  )
}
