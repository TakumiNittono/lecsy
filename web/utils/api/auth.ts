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
  const host = request.headers.get('host')
  
  // 許可されたオリジンリスト
  const allowedOrigins = [
    process.env.NEXT_PUBLIC_SITE_URL,
    'http://localhost:3000',
    'http://localhost:3020',
    'https://localhost:3000',
    'https://localhost:3020',
    'https://lecsy.vercel.app', // Vercel本番環境
    'https://*.vercel.app', // Vercelのプレビュー環境（ワイルドカードは後で処理）
  ].filter(Boolean) as string[]
  
  // 同じオリジンからのリクエスト（Same-Origin Request）の場合は許可
  // Same-Origin Requestでは、Originヘッダーが送信されないことがある
  if (!origin && referer && host) {
    try {
      const refererUrl = new URL(referer)
      // Refererのホストがリクエストのホストと一致する場合は許可
      if (refererUrl.host === host) {
        return true
      }
    } catch {
      // URL解析エラーは無視
    }
  }
  
  // Originヘッダーが存在する場合
  if (origin) {
    // 許可リストに含まれているか確認
    const isAllowed = allowedOrigins.some(allowed => {
      // ワイルドカード対応（*.vercel.app）
      if (allowed.includes('*')) {
        const pattern = allowed.replace('*', '.*')
        const regex = new RegExp(`^${pattern}$`)
        return regex.test(origin)
      }
      return allowed === origin
    })
    
    if (!isAllowed) {
      console.warn(`Origin validation failed: ${origin} not in allowed list`)
      return false
    }
  }
  
  // Refererヘッダーが存在する場合
  if (referer) {
    try {
      const url = new URL(referer)
      const refOrigin = `${url.protocol}//${url.host}`
      
      // 許可リストに含まれているか確認
      const isAllowed = allowedOrigins.some(allowed => {
        // ワイルドカード対応
        if (allowed.includes('*')) {
          const pattern = allowed.replace('*', '.*')
          const regex = new RegExp(`^${pattern}$`)
          return regex.test(refOrigin)
        }
        return allowed === refOrigin
      })
      
      if (!isAllowed) {
        // 同じホストからのリクエストの場合は許可（Same-Origin Request）
        if (host && url.host === host) {
          return true
        }
        console.warn(`Referer validation failed: ${refOrigin} not in allowed list`)
        return false
      }
    } catch {
      // URL解析エラーは無視（Same-Origin Requestの可能性があるため）
      // ただし、hostヘッダーが存在する場合は許可
      if (host) {
        return true
      }
      return false
    }
  }
  
  // OriginもRefererも存在しない場合、Same-Origin Requestの可能性があるため許可
  // （ただし、これは開発環境でのみ発生する可能性が高い）
  // iOSアプリからのリクエストの場合、Origin/Refererが存在しない可能性がある
  if (!origin && !referer) {
    // 開発環境では許可
    if (process.env.NODE_ENV === 'development') {
      return true
    }
    // 本番環境では、hostヘッダーが存在する場合は許可
    // iOSアプリからのリクエストの場合、認証トークンで検証するため、Origin検証をスキップ
    if (host) {
      return true
    }
    // iOSアプリからのリクエストの場合、認証トークンで検証するため、Origin検証をスキップ
    // User-AgentヘッダーでiOSアプリからのリクエストかどうかを判断
    const userAgent = request.headers.get('user-agent')
    if (userAgent && (userAgent.includes('iOS') || userAgent.includes('iPhone') || userAgent.includes('iPad'))) {
      return true
    }
  }
  
  return true
}
