'use client'

import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          const cookies: Array<{ name: string; value: string }> = []
          if (typeof document !== 'undefined') {
            document.cookie.split('; ').forEach(cookie => {
              const [name, ...rest] = cookie.split('=')
              if (name) {
                cookies.push({
                  name: name.trim(),
                  value: decodeURIComponent(rest.join('='))
                })
              }
            })
          }
          return cookies
        },
        setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
          if (typeof document === 'undefined') return
          
          cookiesToSet.forEach(({ name, value, options }) => {
            const parts: string[] = []
            
            // 値
            parts.push(`${name}=${encodeURIComponent(value)}`)
            
            // オプション
            if (options?.path) parts.push(`path=${options.path}`)
            if (options?.maxAge) parts.push(`max-age=${options.maxAge}`)
            if (options?.expires) parts.push(`expires=${options.expires}`)
            
            // SameSite (重要: LaxまたはNone)
            const sameSite = options?.sameSite || 'Lax'
            parts.push(`SameSite=${sameSite}`)
            
            // Secure (HTTPSの場合)
            if (options?.secure !== false && window.location.protocol === 'https:') {
              parts.push('Secure')
            }
            
            // Domain
            if (options?.domain) parts.push(`domain=${options.domain}`)
            
            document.cookie = parts.join('; ')
          })
        },
      },
    }
  )
}
