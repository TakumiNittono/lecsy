import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

// 動的レンダリングを強制（request.urlを使用するため）
export const dynamic = 'force-dynamic'

async function handleCallback(request: NextRequest) {
  const requestUrl = new URL(request.url)
  
  // GETリクエストの場合（Google OAuthなど）
  let code = requestUrl.searchParams.get('code')
  let error = requestUrl.searchParams.get('error')
  let errorDescription = requestUrl.searchParams.get('error_description')
  let state = requestUrl.searchParams.get('state')
  
  // POSTリクエストの場合（Apple OAuth form_postモードなど）
  if (request.method === 'POST') {
    try {
      const formData = await request.formData()
      code = formData.get('code') as string | null
      error = formData.get('error') as string | null
      errorDescription = formData.get('error_description') as string | null
      state = formData.get('state') as string | null
    } catch (err) {
      console.error('Failed to parse form data:', err)
    }
  }
  
  const next = requestUrl.searchParams.get('next') || '/app'

  // 環境変数の確認
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('Missing Supabase environment variables')
    return NextResponse.redirect(
      new URL('/login?error=' + encodeURIComponent('サーバー設定エラー'), requestUrl.origin)
    )
  }

  if (error) {
    console.error('OAuth error:', error, errorDescription)
    return NextResponse.redirect(
      new URL(`/login?error=${encodeURIComponent(error)}`, requestUrl.origin)
    )
  }

  if (!code) {
    console.error('No code parameter found in callback')
    return NextResponse.redirect(
      new URL('/login?error=' + encodeURIComponent('認証コードが見つかりません'), requestUrl.origin)
    )
  }

  try {
    let supabaseResponse = NextResponse.next({
      request,
    })

    const supabase = createServerClient(
      supabaseUrl,
      supabaseAnonKey,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll()
          },
          setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
            cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
            supabaseResponse = NextResponse.next({
              request,
            })
            cookiesToSet.forEach(({ name, value, options }) =>
              supabaseResponse.cookies.set(name, value, options)
            )
          },
        },
      }
    )
    
    console.log('Exchanging code for session...', { code: code.substring(0, 20) + '...' })
    const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)

    if (exchangeError) {
      console.error('Exchange error:', {
        message: exchangeError.message,
        status: exchangeError.status,
        name: exchangeError.name,
      })
      return NextResponse.redirect(
        new URL(
          `/login?error=${encodeURIComponent(exchangeError.message || '認証に失敗しました')}`,
          requestUrl.origin
        )
      )
    }

    if (!data?.user) {
      console.error('No user data returned from exchange')
      return NextResponse.redirect(
        new URL('/login?error=' + encodeURIComponent('ユーザー情報の取得に失敗しました'), requestUrl.origin)
      )
    }

    console.log('Authentication successful:', { userId: data.user.id })
    
    // 認証成功 - リダイレクト（クッキーを含む）
    const redirectResponse = NextResponse.redirect(new URL(next, requestUrl.origin))
    
    // セッションクッキーをコピー
    supabaseResponse.cookies.getAll().forEach((cookie) => {
      redirectResponse.cookies.set(cookie.name, cookie.value, {
        path: cookie.path || '/',
        sameSite: cookie.sameSite as 'lax' | 'strict' | 'none' | undefined,
        secure: cookie.secure ?? true,
        httpOnly: cookie.httpOnly ?? true,
        maxAge: cookie.maxAge,
      })
    })
    
    return redirectResponse
  } catch (err: any) {
    console.error('Unexpected error in callback handler:', {
      message: err?.message,
      stack: err?.stack,
    })
    return NextResponse.redirect(
      new URL(
        `/login?error=${encodeURIComponent(err?.message || '予期しないエラーが発生しました')}`,
        requestUrl.origin
      )
    )
  }
}

export async function GET(request: NextRequest) {
  return handleCallback(request)
}

export async function POST(request: NextRequest) {
  return handleCallback(request)
}
