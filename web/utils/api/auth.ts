import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

export interface AuthenticatedUser {
  id: string
  email?: string
}

export interface AuthResult {
  user: AuthenticatedUser | null
  error: NextResponse | null
}

/**
 * APIルートで認証チェックを行う
 * @returns user: 認証されたユーザー、error: エラーレスポンス
 */
export async function authenticateRequest(): Promise<AuthResult> {
  try {
    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError) {
      console.error('Authentication error:', authError)
      return {
        user: null,
        error: NextResponse.json(
          { error: 'Authentication failed' },
          { status: 401 }
        )
      }
    }

    if (!user) {
      return {
        user: null,
        error: NextResponse.json(
          { error: 'Unauthorized' },
          { status: 401 }
        )
      }
    }

    return {
      user: {
        id: user.id,
        email: user.email
      },
      error: null
    }
  } catch (error) {
    console.error('Unexpected auth error:', error)
    return {
      user: null,
      error: NextResponse.json(
        { error: 'Internal server error' },
        { status: 500 }
      )
    }
  }
}

/**
 * UUIDの形式を検証
 */
export function isValidUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  return uuidRegex.test(id)
}

/**
 * OriginとRefererを検証（簡易CSRF対策）
 */
export function validateOrigin(request: Request): boolean {
  const origin = request.headers.get('origin')
  const referer = request.headers.get('referer')
  
  const allowedOrigins = [
    process.env.NEXT_PUBLIC_SITE_URL,
    'http://localhost:3000',
    'https://localhost:3000',
  ].filter(Boolean) as string[]
  
  if (origin && !allowedOrigins.includes(origin)) {
    return false
  }
  
  if (referer) {
    try {
      const url = new URL(referer)
      const refOrigin = `${url.protocol}//${url.host}`
      if (!allowedOrigins.includes(refOrigin)) {
        return false
      }
    } catch {
      return false
    }
  }
  
  return true
}
