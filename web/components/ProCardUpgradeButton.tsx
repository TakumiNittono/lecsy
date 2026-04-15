'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/utils/supabase/client'
import Link from 'next/link'

// "Free Until June 1" campaign: every feature is open to all signed-in users.
// Signed-in users see a go-to-library CTA; signed-out users see sign-in CTA.
// No paid upgrade exists right now.
export default function ProCardUpgradeButton() {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        setIsLoggedIn(!!user)
      } catch {
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

  const href = isLoggedIn ? '/app' : '/login'
  const label = isLoggedIn ? 'Open Your Library' : 'Get Started — 100% Free'

  return (
    <Link
      href={href}
      className="block w-full px-6 py-4 bg-white text-blue-600 rounded-xl font-semibold text-center hover:bg-gray-100 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
    >
      {label}
    </Link>
  )
}
