'use client'

import { useState } from 'react'
import UpgradeButton from './UpgradeButton'

interface ProFeatureButtonProps {
  isPro: boolean
  featureName: string
  onProClick?: () => void
}

export default function ProFeatureButton({ isPro, featureName, onProClick }: ProFeatureButtonProps) {
  const [loading, setLoading] = useState(false)

  if (!isPro) {
    return (
      <div className="p-4 bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg border border-blue-200">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm font-semibold text-gray-900">{featureName}</span>
          <span className="px-2 py-1 bg-blue-600 text-white text-xs rounded-full font-semibold">Pro</span>
        </div>
        <p className="text-xs text-gray-600 mb-3">
          Upgrade to Pro to unlock {featureName.toLowerCase()}
        </p>
        <UpgradeButton className="w-full text-sm py-2" />
      </div>
    )
  }

  const handleClick = async () => {
    if (onProClick) {
      setLoading(true)
      try {
        await onProClick()
      } finally {
        setLoading(false)
      }
    }
  }

  return (
    <button
      onClick={handleClick}
      disabled={loading || !onProClick}
      className="px-4 py-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg font-semibold hover:from-blue-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
    >
      {loading ? (
        <span className="flex items-center gap-2">
          <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Loading...
        </span>
      ) : (
        `Use ${featureName}`
      )}
    </button>
  )
}
