import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
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

  // 認証コールバックパスではセッションチェックをスキップ
  if (request.nextUrl.pathname.startsWith('/auth/callback')) {
    return supabaseResponse
  }

  // ルートパス（LP）とログインページ、公開ページは認証不要
  const path = request.nextUrl.pathname
  const publicPages = new Set([
    '/',
    '/privacy',
    '/terms',
    '/pricing',
    '/support',
    '/ai-transcription-for-students',
    '/lecture-recording-app-college',
    '/ai-note-taking-for-international-students',
    '/otter-alternative-for-lectures',
    '/how-to-record-lectures-legally',
    // Crawler / static assets — must be reachable without a session,
    // otherwise Googlebot gets 307→/login and can't index the site.
    '/sitemap.xml',
    '/robots.txt',
    '/icon.png',
    '/apple-icon.png',
    '/og-image.jpg',
    '/opengraph-image',
    '/manifest.webmanifest',
    '/manifest.json',
    '/sw.js',
    '/mp3',  // 母用 MP3 文字起こしページ (PINゲート)
  ])
  // /login は publicPages 扱いだが、既ログインユーザーは /app (or ?redirectTo=...)
  // に即リダイレクトする。以前は LoginForm 側の useEffect で Supabase Client を
  // 動的 import → getSession() → redirect していたが、これが /login の LCP を
  // 3.3s に膨らませていた。middleware で判定すれば HTML を返す前に redirect
  // できるので、未ログインの人には空の追加処理ゼロでログインフォームが即出る。
  if (path.startsWith('/login')) {
    const { data: { user: authedUser } } = await supabase.auth.getUser()
    if (authedUser) {
      const redirectParam = request.nextUrl.searchParams.get('redirectTo') || '/app'
      // open redirect 対策: 自サイト配下の pathname のみ許可
      const safeRedirect = redirectParam.startsWith('/') && !redirectParam.startsWith('//')
        ? redirectParam
        : '/app'
      const url = request.nextUrl.clone()
      url.pathname = safeRedirect
      url.search = ''
      return NextResponse.redirect(url)
    }
    return supabaseResponse
  }

  // /admin/login はオペレーター用の公開エントリ。/login が招待コード専用に
  // なったので、super-admin が自分のアカウントでサインインする入口がここ
  // しかない。super-admin かどうかは /admin の page 側で再チェックする。
  if (path === '/admin/login' || path === '/admin/login/') {
    const { data: { user: authedUser } } = await supabase.auth.getUser()
    if (authedUser) {
      const url = request.nextUrl.clone()
      url.pathname = '/admin'
      url.search = ''
      return NextResponse.redirect(url)
    }
    return supabaseResponse
  }

  // /android entry is public (it's the invite-code gate itself).
  // /android/* deeper paths require an authenticated session (anon redeemed)
  // and are routed back to /android by the page if no membership exists.
  if (path === '/android' || path === '/android/') {
    return supabaseResponse
  }
  if (path.startsWith('/android/')) {
    const { data: { user: androidUser } } = await supabase.auth.getUser()
    if (!androidUser) {
      const url = request.nextUrl.clone()
      url.pathname = '/android'
      return NextResponse.redirect(url)
    }
    return supabaseResponse
  }

  if (
    publicPages.has(path) ||
    path.startsWith('/auth') ||
    path.startsWith('/schools') ||
    path.startsWith('/join')
  ) {
    return supabaseResponse
  }

  // セッションをリフレッシュ
  const {
    data: { user },
  } = await supabase.auth.getUser()

  // 認証が必要なページ（/app, /org/**, /admin/** など）へのアクセスを保護
  const isProtectedB2B = path.startsWith('/org') || path.startsWith('/admin')
  if (!user) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    if (isProtectedB2B) {
      url.searchParams.set('redirect', path)
    }
    return NextResponse.redirect(url)
  }

  // NOTE on /org/[slug]/** authorization:
  // We intentionally do NOT run the "am I a member of this slug" DB check in
  // middleware. Previous iterations did, but middleware runs on every request
  // including RSC prefetches + subresources, so /org/* navigations were paying
  // for a redundant organizations + organization_members round-trip every
  // time — contributed ~400ms of a ~7s LCP on the members dashboard.
  //
  // Authorization is now centralized in:
  //   - web/app/org/[slug]/layout.tsx → getOrgMembership(slug) (cache()-de-duped)
  //   - web/app/api/org/[slug]/**      → requireOrgRole(slug, role)
  // Both redirect non-members to /app, so middleware only needs to ensure the
  // user is authenticated (handled above) — the membership check above this
  // comment has been removed deliberately.

  return supabaseResponse
}
