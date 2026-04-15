'use client'

import { useState } from 'react'

// "Free Until June 1": no Pro gate. Every signed-in user can use every feature.
// Kept as a thin action button so existing call sites still compile.

interface ProFeatureButtonProps {
  /** Retained for backwards compatibility. Currently ignored — all users have access. */
  isPro?: boolean
  featureName: string
  onProClick?: () => void
}

export default function ProFeatureButton({ featureName, onProClick }: ProFeatureButtonProps) {
  const [loading, setLoading] = useState(false)

  const handleClick = async () => {
    if (!onProClick) return
    setLoading(true)
    try {
      await onProClick()
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleClick}
      disabled={loading || !onProClick}
      className="px-4 py-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg font-semibold hover:from-blue-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
    >
      {loading ? 'Loading...' : `Use ${featureName}`}
    </button>
  )
}
