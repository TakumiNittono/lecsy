'use client'

import { useEffect, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@/utils/supabase/client'

function AuthCallbackContent() {
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const handleCallback = async () => {
      const code = searchParams.get('code')
      const next = searchParams.get('next') || '/app'
      const error = searchParams.get('error')
      const errorDescription = searchParams.get('error_description')

      if (error) {
        console.error('OAuth error:', error, errorDescription)
        router.push(`/login?error=${encodeURIComponent(error)}`)
        return
      }

      if (code) {
        try {
          const supabase = createClient()
          console.log('Exchanging code for session...')
          const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)

          console.log('Exchange result:', {
            hasData: !!data,
            error: exchangeError?.message,
            hasUser: !!data?.user,
          })

          if (!exchangeError && data?.user) {
            console.log('Authentication successful, redirecting to:', next)
            router.push(next)
          } else {
            console.error('Exchange error:', exchangeError)
            router.push(`/login?error=${encodeURIComponent(exchangeError?.message || '認証に失敗しました')}`)
          }
        } catch (err: any) {
          console.error('Callback error:', err)
          router.push(`/login?error=${encodeURIComponent(err.message || '予期しないエラーが発生しました')}`)
        }
      } else {
        console.log('No code parameter, redirecting to login')
        router.push('/login')
      }
    }

    handleCallback()
  }, [searchParams, router])

  return (
    <main className="min-h-screen bg-white flex items-center justify-center">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
        <p className="text-gray-600">認証を処理しています...</p>
      </div>
    </main>
  )
}

export default function AuthCallback() {
  return (
    <Suspense fallback={
      <main className="min-h-screen bg-white flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">読み込み中...</p>
        </div>
      </main>
    }>
      <AuthCallbackContent />
    </Suspense>
  )
}
