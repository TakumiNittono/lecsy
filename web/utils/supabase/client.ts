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
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            let cookieString = `${name}=${encodeURIComponent(value)}`
            
            if (options?.maxAge) {
              cookieString += `; max-age=${options.maxAge}`
            }
            if (options?.expires) {
              cookieString += `; expires=${options.expires}`
            }
            if (options?.path) {
              cookieString += `; path=${options.path}`
            } else {
              cookieString += `; path=/`
            }
            if (options?.domain) {
              cookieString += `; domain=${options.domain}`
            }
            if (options?.sameSite) {
              cookieString += `; SameSite=${options.sameSite}`
            } else {
              cookieString += `; SameSite=Lax`
            }
            if (options?.secure || window.location.protocol === 'https:') {
              cookieString += `; Secure`
            }
            
            document.cookie = cookieString
          })
        },
      },
    }
  )
}
