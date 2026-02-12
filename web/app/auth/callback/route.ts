import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'
import { getSafeRedirectPath } from '@/utils/redirect'

// 動的レンダリングを強制（request.urlを使用するため）
export const dynamic = 'force-dynamic'

async function handleCallback(request: NextRequest) {
  const requestUrl = new URL(request.url)
  if (process.env.NODE_ENV === 'development') {
    console.log('Callback received:', { method: request.method, pathname: requestUrl.pathname })
  }
  
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
      console.log('POST form data parsed:', { hasCode: !!code, hasError: !!error })
    } catch (err) {
      console.error('Failed to parse form data:', err)
    }
  }
  
  // オープンリダイレクト対策: リダイレクト先を検証
  const nextParam = requestUrl.searchParams.get('next') || '/app'
  const next = getSafeRedirectPath(nextParam, '/app')

  // 環境変数の確認
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('Missing Supabase environment variables', {
      hasUrl: !!supabaseUrl,
      hasKey: !!supabaseAnonKey,
    })
    return NextResponse.redirect(
      new URL('/login?error=' + encodeURIComponent('サーバー設定エラー'), requestUrl.origin)
    )
  }

  if (error) {
    console.error('OAuth error received:', {
      error,
      errorDescription,
      state,
    })
    const errorMessage = errorDescription || error || '認証に失敗しました'
    return NextResponse.redirect(
      new URL(`/login?error=${encodeURIComponent(errorMessage)}`, requestUrl.origin)
    )
  }

  if (!code) {
    console.error('No code parameter found in callback', {
      method: request.method,
      searchParams: Object.fromEntries(requestUrl.searchParams),
    })
    return NextResponse.redirect(
      new URL('/login?error=' + encodeURIComponent('認証コードが見つかりません。もう一度ログインをお試しください。'), requestUrl.origin)
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
      if (process.env.NODE_ENV === 'development') {
        console.error('Exchange error:', exchangeError)
      }
      const errorMsg = process.env.NODE_ENV === 'development'
        ? (exchangeError.message || '認証に失敗しました')
        : '認証に失敗しました'
      return NextResponse.redirect(
        new URL(`/login?error=${encodeURIComponent(errorMsg)}`, requestUrl.origin)
      )
    }

    if (!data?.user) {
      console.error('No user data returned from exchange')
      return NextResponse.redirect(
        new URL('/login?error=' + encodeURIComponent('ユーザー情報の取得に失敗しました'), requestUrl.origin)
      )
    }

    console.log('Authentication successful:', { userId: data.user.id })
    
    // セッションが確立されたことを確認（リトライロジック付き）
    let sessionConfirmed = false
    let retryCount = 0
    const maxRetries = 3
    
    while (!sessionConfirmed && retryCount < maxRetries) {
      // 少し待ってからセッションを確認
      if (retryCount > 0) {
        await new Promise(resolve => setTimeout(resolve, 500 * retryCount))
      }
      
      const { data: { session }, error: sessionError } = await supabase.auth.getSession()
      
      if (sessionError) {
        console.error(`Session check error (attempt ${retryCount + 1}):`, sessionError)
      }
      
      if (session?.user?.id === data.user.id) {
        sessionConfirmed = true
        console.log('Session confirmed:', { userId: session.user.id })
      } else {
        retryCount++
        console.warn(`Session not confirmed yet (attempt ${retryCount}/${maxRetries})`)
      }
    }
    
    if (!sessionConfirmed) {
      console.error('Session confirmation failed after retries')
      return NextResponse.redirect(
        new URL('/login?error=' + encodeURIComponent('セッションの確立に失敗しました。もう一度お試しください。'), requestUrl.origin)
      )
    }
    
    // 認証成功 - リダイレクト（クッキーを含む）
    const redirectResponse = NextResponse.redirect(new URL(next, requestUrl.origin))
    
    // セッションクッキーを確実にコピー
    const allCookies = supabaseResponse.cookies.getAll()
    console.log('Copying cookies to redirect response:', allCookies.length, 'cookies')
    
    allCookies.forEach((cookie) => {
      redirectResponse.cookies.set(cookie.name, cookie.value, {
        path: cookie.path || '/',
        sameSite: (cookie.sameSite as 'lax' | 'strict' | 'none') || 'lax',
        secure: cookie.secure ?? (requestUrl.protocol === 'https:'),
        httpOnly: cookie.httpOnly ?? true,
        maxAge: cookie.maxAge,
        domain: cookie.domain,
      })
    })
    
    // セッションクッキーが確実に設定されていることを確認
    const sessionCookie = allCookies.find(c => c.name.includes('auth-token') || c.name.includes('sb-'))
    if (!sessionCookie) {
      console.warn('No session cookie found, but proceeding with redirect')
    }
    
    return redirectResponse
  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : '予期しないエラーが発生しました'
    if (process.env.NODE_ENV === 'development') {
      console.error('Unexpected error in callback handler:', err)
    }
    const errorMsg = process.env.NODE_ENV === 'development' ? errMsg : '予期しないエラーが発生しました'
    return NextResponse.redirect(
      new URL(`/login?error=${encodeURIComponent(errorMsg)}`, requestUrl.origin)
    )
  }
}

export async function GET(request: NextRequest) {
  return handleCallback(request)
}

export async function POST(request: NextRequest) {
  return handleCallback(request)
}
