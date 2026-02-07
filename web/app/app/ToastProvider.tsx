'use client'

import { useEffect, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import Toast from '@/components/Toast'

export default function ToastProvider() {
  const searchParams = useSearchParams()
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null)

  useEffect(() => {
    const success = searchParams.get('success')
    const canceled = searchParams.get('canceled')

    if (success === 'true') {
      setToast({
        message: 'Welcome to Pro! AI features are now available.',
        type: 'success'
      })
      // URLからクエリパラメータを削除
      window.history.replaceState({}, '', window.location.pathname)
    } else if (canceled === 'true') {
      setToast({
        message: 'Checkout canceled. You can upgrade anytime.',
        type: 'info'
      })
      // URLからクエリパラメータを削除
      window.history.replaceState({}, '', window.location.pathname)
    }
  }, [searchParams])

  if (!toast) return null

  return (
    <Toast
      message={toast.message}
      type={toast.type}
      onClose={() => setToast(null)}
    />
  )
}
