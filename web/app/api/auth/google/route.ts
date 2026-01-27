import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const redirectTo = searchParams.get('redirectTo') || '/app'

    // 環境変数の確認
    if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
      return NextResponse.json(
        { error: 'Supabase環境変数が設定されていません' },
        { status: 500 }
      )
    }

    const supabase = createClient()
    
    const origin = request.headers.get('origin') || process.env.NEXT_PUBLIC_APP_URL || 'https://lecsy.vercel.app'
    const callbackUrl = `${origin}/auth/callback?next=${encodeURIComponent(redirectTo)}`
    
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: callbackUrl,
      },
    })

    if (error) {
      console.error('OAuth error:', error)
      return NextResponse.json({ error: error.message }, { status: 400 })
    }

    if (data?.url) {
      // URLをJSONで返す（リダイレクトではなく）
      return NextResponse.json({ url: data.url }, {
        headers: {
          'Content-Type': 'application/json',
        },
      })
    }

    return NextResponse.json({ error: 'Failed to get OAuth URL' }, { status: 500 })
  } catch (error: any) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: error.message || 'Internal server error' },
      { status: 500 }
    )
  }
}
