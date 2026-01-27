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
            return { name: name.trim(), value: decodeURIComponent(rest.join('=')) }
          }).filter(cookie => cookie.name)
        },
        setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
          cookiesToSet.forEach(({ name, value, options }) => {
            const cookieOptions: string[] = []
            
            if (options?.path) cookieOptions.push(`path=${options.path}`)
            if (options?.maxAge) cookieOptions.push(`max-age=${options.maxAge}`)
            if (options?.expires) cookieOptions.push(`expires=${options.expires}`)
            if (options?.sameSite) cookieOptions.push(`SameSite=${options.sameSite}`)
            if (options?.secure) cookieOptions.push('Secure')
            if (options?.domain) cookieOptions.push(`domain=${options.domain}`)
            
            const cookieString = `${name}=${encodeURIComponent(value)}${cookieOptions.length > 0 ? '; ' + cookieOptions.join('; ') : ''}`
            document.cookie = cookieString
          })
        },
      },
    }
  )
}
