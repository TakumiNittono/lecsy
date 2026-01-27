'use client'

interface DeleteButtonProps {
  onDelete: () => void
}

export default function DeleteButton({ onDelete }: DeleteButtonProps) {
  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
    if (!confirm('Are you sure you want to delete this lecture?')) {
      e.preventDefault()
      return
    }
    onDelete()
  }

  return (
    <button
      type="submit"
      onClick={handleClick}
      className="px-4 py-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors font-medium"
    >
      Delete
    </button>
  )
}
