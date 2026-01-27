'use client'

import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          if (typeof document === 'undefined') return []
          if (!document.cookie) return []
          
          return document.cookie.split('; ').map(cookie => {
            const [name, ...rest] = cookie.split('=')
            if (!name) return null
            return {
              name: name.trim(),
              value: rest.length > 0 ? decodeURIComponent(rest.join('=')) : ''
            }
          }).filter((cookie): cookie is { name: string; value: string } => cookie !== null)
        },
        setAll(cookiesToSet) {
          if (typeof document === 'undefined') return
          
          cookiesToSet.forEach(({ name, value, options }) => {
            if (!name) return
            
            let cookieString = `${name}=${encodeURIComponent(value || '')}`
            
            // デフォルトでpath=/を設定（重要: PKCE code verifierが正しく保存されるため）
            cookieString += `; path=/`
            
            if (options?.maxAge) {
              cookieString += `; max-age=${options.maxAge}`
            }
            if (options?.expires) {
              cookieString += `; expires=${options.expires}`
            }
            if (options?.path) {
              cookieString = cookieString.replace('; path=/', `; path=${options.path}`)
            }
            if (options?.domain) {
              cookieString += `; domain=${options.domain}`
            }
            if (options?.sameSite) {
              cookieString += `; SameSite=${options.sameSite}`
            } else {
              cookieString += `; SameSite=Lax`
            }
            if (options?.secure !== false && window.location.protocol === 'https:') {
              cookieString += `; Secure`
            }
            
            document.cookie = cookieString
          })
        },
      },
    }
  )
}
