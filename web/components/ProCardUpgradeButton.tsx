'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/utils/supabase/client'
import Link from 'next/link'
import UpgradeButton from './UpgradeButton'

export default function ProCardUpgradeButton() {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        setIsLoggedIn(!!user)
      } catch (error) {
        setIsLoggedIn(false)
      } finally {
        setLoading(false)
      }
    }

    checkAuth()
  }, [])

  if (loading) {
    return (
      <div className="w-full px-6 py-4 bg-white/20 text-white rounded-xl font-semibold text-center opacity-50">
        Loading...
      </div>
    )
  }

  if (isLoggedIn) {
    return (
      <button
        onClick={async () => {
          try {
            const res = await fetch('/api/create-checkout-session', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              credentials: 'include', // Cookie（認証）を確実に送信
            })
            if (!res.ok) throw new Error('Failed to create checkout session')
            const data = await res.json()
            if (data.url) window.location.href = data.url
          } catch (error) {
            alert('Something went wrong. Please try again.')
          }
        }}
        className="w-full px-6 py-4 bg-white text-blue-600 rounded-xl font-semibold hover:bg-gray-100 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
      >
        Upgrade to Pro — $2.99/mo
      </button>
    )
  }

  return (
    <Link
      href="/login"
      className="block w-full px-6 py-4 bg-white text-blue-600 rounded-xl font-semibold text-center hover:bg-gray-100 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
    >
      Get Started — Free
    </Link>
  )
}
