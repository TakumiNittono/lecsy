import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')
  const next = requestUrl.searchParams.get('next') ?? '/app'
  const error = requestUrl.searchParams.get('error')
  const errorDescription = requestUrl.searchParams.get('error_description')

  console.log('Auth callback:', { code: !!code, error, errorDescription, next })

  // エラーパラメータがある場合
  if (error) {
    console.error('OAuth error:', error, errorDescription)
    const loginUrl = new URL('/login', requestUrl.origin)
    loginUrl.searchParams.set('error', error)
    if (errorDescription) {
      loginUrl.searchParams.set('error_description', errorDescription)
    }
    return NextResponse.redirect(loginUrl)
  }

  if (code) {
    try {
      const supabase = createClient()
      console.log('Exchanging code for session...')
      const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)
      
      console.log('Exchange result:', { 
        hasData: !!data, 
        error: exchangeError?.message,
        hasUser: !!data?.user 
      })
      
      if (!exchangeError && data?.user) {
        // リダイレクト先のURLを構築
        const redirectUrl = new URL(next, requestUrl.origin)
        console.log('Redirecting to:', redirectUrl.toString())
        return NextResponse.redirect(redirectUrl)
      } else {
        console.error('Exchange error:', exchangeError)
        const loginUrl = new URL('/login', requestUrl.origin)
        loginUrl.searchParams.set('error', exchangeError?.message || '認証に失敗しました')
        return NextResponse.redirect(loginUrl)
      }
    } catch (err: any) {
      console.error('Callback error:', err)
      const loginUrl = new URL('/login', requestUrl.origin)
      loginUrl.searchParams.set('error', err.message || '予期しないエラーが発生しました')
      return NextResponse.redirect(loginUrl)
    }
  }

  // codeがない場合はログインページにリダイレクト
  console.log('No code parameter, redirecting to login')
  return NextResponse.redirect(new URL('/login', requestUrl.origin))
}
