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
    '/ai-transcription-for-students',
    '/lecture-recording-app-college',
    '/ai-note-taking-for-international-students',
    '/otter-alternative-for-lectures',
    '/how-to-record-lectures-legally',
  ])
  if (
    publicPages.has(path) ||
    path.startsWith('/login') ||
    path.startsWith('/auth')
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

  // /org/[slug]/** : 非メンバーは /app へ追い返す（防御の二段目）
  // ページ側でも getOrgMembership で再チェックされるが、ここで先に弾く。
  // /org/create など slug を持たないトップレベルは除外する。
  const orgMatch = path.match(/^\/org\/([^/]+)(?:\/|$)/)
  if (orgMatch) {
    const slug = orgMatch[1]
    // slug が予約語（create, new など）の場合はスキップ
    const reserved = new Set(['create', 'new'])
    if (!reserved.has(slug)) {
      // RLS 経由で organizations + 自分の active membership をチェック。
      // anon キー + ユーザーセッション cookie で動作するので、
      // is_org_member() RLS を信頼する。
      const { data: org } = await supabase
        .from('organizations')
        .select('id')
        .eq('slug', slug)
        .maybeSingle()

      let allowed = false
      if (org) {
        const { data: member } = await supabase
          .from('organization_members')
          .select('role')
          .eq('org_id', org.id)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle()
        allowed = !!member
      }

      if (!allowed) {
        const url = request.nextUrl.clone()
        url.pathname = '/app'
        url.search = ''
        return NextResponse.redirect(url)
      }
    }
  }

  return supabaseResponse
}
