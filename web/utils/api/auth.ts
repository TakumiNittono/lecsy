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
 */
export async function authenticateRequest(): Promise<AuthResult> {
  try {
    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError) {
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
  } catch {
    return {
      user: null,
      error: NextResponse.json(
        { error: 'Internal server error' },
        { status: 500 }
      )
    }
  }
}

// リダイレクト検証（オープンリダイレクト対策）
export { isValidRedirectPath, getSafeRedirectPath } from '@/utils/redirect'

/**
 * UUIDの形式を検証
 */
export function isValidUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  return uuidRegex.test(id)
}

/**
 * 許可されたオリジンのリスト
 */
function getAllowedOrigins(): string[] {
  const origins = [
    'https://lecsy.vercel.app',
    'https://lecsy.app',
    'https://www.lecsy.app',
  ]

  // 環境変数から追加のオリジン
  if (process.env.NEXT_PUBLIC_SITE_URL) origins.push(process.env.NEXT_PUBLIC_SITE_URL)
  if (process.env.NEXT_PUBLIC_APP_URL) origins.push(process.env.NEXT_PUBLIC_APP_URL)
  if (process.env.VERCEL_URL) origins.push(`https://${process.env.VERCEL_URL}`)

  // 開発環境のみ localhost を許可
  if (process.env.NODE_ENV === 'development') {
    origins.push('http://localhost:3000', 'http://localhost:3020')
  }

  return [...new Set(origins)]
}

/**
 * OriginまたはRefererが許可リストに含まれるか検証（CSRF対策）
 * デフォルト拒否: Origin/Refererが不明な場合はブロック
 */
export function validateOrigin(request: Request): boolean {
  const origin = request.headers.get('origin')
  const referer = request.headers.get('referer')
  const allowedOrigins = getAllowedOrigins()

  // Originヘッダーがある場合（ブラウザのPOST/DELETE/PATCHでは必ず送信される）
  if (origin) {
    return allowedOrigins.includes(origin)
  }

  // Refererヘッダーのオリジン部分で判定
  if (referer) {
    try {
      const refererOrigin = new URL(referer).origin
      return allowedOrigins.includes(refererOrigin)
    } catch {
      return false
    }
  }

  // Origin も Referer もない場合
  // 開発環境では許可、本番ではブロック
  return process.env.NODE_ENV === 'development'
}
