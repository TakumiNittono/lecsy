'use client'

// Supabase auth state を Sentry の user scope に同期する薄いクライアントコンポーネント。
// root layout に差し込んでおけば、どのページでも以下が自動実現:
//   - 初回マウント時: 現 session があれば Sentry.setUser(user)
//   - ログイン/ログアウト/切替時: onAuthStateChange を通じて setUser 更新
//   - セッション終了: setUser(null)
//
// PII は email のみ送出 (sendDefaultPii=false で IP は送らない)。

import { useEffect } from 'react'
import * as Sentry from '@sentry/nextjs'
import { createClient } from '@/utils/supabase/client'

export default function SentryUserBinding() {
  useEffect(() => {
    const supabase = createClient()

    // 初期化時の現 session
    supabase.auth.getUser().then(({ data }) => {
      bind(data.user)
    })

    // 以後の変化
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      bind(session?.user ?? null)
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  return null
}

function bind(user: { id: string; email?: string | null } | null) {
  if (!user) {
    Sentry.setUser(null)
    return
  }
  Sentry.setUser({
    id: user.id,
    email: user.email ?? undefined,
  })
}
