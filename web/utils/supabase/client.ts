'use client'

import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return document.cookie.split('; ').map(cookie => {
            const [name, ...rest] = cookie.split('=')
            return { 
              name: name.trim(), 
              value: decodeURIComponent(rest.join('=')) 
            }
          }).filter(cookie => cookie.name)
        },
        setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
          cookiesToSet.forEach(({ name, value, options }) => {
            const cookieOptions: string[] = []
            
            // デフォルト値を設定
            const path = options?.path || '/'
            const maxAge = options?.maxAge || 60 * 60 * 24 * 365 // 1年
            const sameSite = options?.sameSite || 'Lax'
            const secure = options?.secure !== undefined ? options.secure : window.location.protocol === 'https:'
            
            cookieOptions.push(`path=${path}`)
            cookieOptions.push(`max-age=${maxAge}`)
            cookieOptions.push(`SameSite=${sameSite}`)
            if (secure) {
              cookieOptions.push('Secure')
            }
            if (options?.domain) {
              cookieOptions.push(`domain=${options.domain}`)
            }
            
            const cookieString = `${name}=${encodeURIComponent(value)}; ${cookieOptions.join('; ')}`
            document.cookie = cookieString
          })
        },
      },
    }
  )
}
