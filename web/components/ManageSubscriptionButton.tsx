'use client'

import { useState } from 'react'

interface ManageSubscriptionButtonProps {
  className?: string
}

export default function ManageSubscriptionButton({ className = '' }: ManageSubscriptionButtonProps) {
  const [loading, setLoading] = useState(false)

  const handleManage = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/create-portal-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include', // Cookie（認証）を確実に送信
      })

      if (!res.ok) {
        const error = await res.json()
        throw new Error(error.error || 'Failed to create portal session')
      }

      const data = await res.json()
      if (data.url) {
        window.location.href = data.url
      } else {
        throw new Error('No portal URL returned')
      }
    } catch (error) {
      console.error('Portal error:', error)
      alert(error instanceof Error ? error.message : 'Something went wrong. Please try again.')
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleManage}
      disabled={loading}
      className={`text-sm text-blue-600 hover:text-blue-800 underline disabled:opacity-50 disabled:cursor-not-allowed ${className}`}
    >
      {loading ? 'Loading...' : 'Manage Subscription'}
    </button>
  )
}
