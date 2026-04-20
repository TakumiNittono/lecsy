"use client";

import Link from "next/link";
import { useState, useEffect, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { getSafeRedirectPath } from "@/utils/redirect";

function LoginForm() {
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const searchParams = useSearchParams();
  // オープンリダイレクト対策: redirectToを検証
  const redirectTo = getSafeRedirectPath(searchParams.get('redirectTo'), '/app');

  // Session check は middleware が担当するので client 側ではやらない。
  // 以前は useEffect で Supabase client を動的 import → getSession() →
  // redirect していたため /login 開いてから 3秒以上ボタンが出なかった。
  // middleware なら HTML を返す前に /app へ飛ばせるのでこの遅延はゼロ。
  useEffect(() => {
    const errorParam = searchParams.get('error');
    if (errorParam) {
      setError(decodeURIComponent(errorParam));
    }
  }, [searchParams]);

  const handleMicrosoftLogin = async () => {
    try {
      setLoading(true);
      setError(null);

      const { createClient } = await import('@/utils/supabase/client')
      const supabase = createClient()

      const redirectUrl = `${window.location.origin}/auth/callback?next=${encodeURIComponent(redirectTo)}`

      const { data, error: signInError } = await supabase.auth.signInWithOAuth({
        provider: 'azure',
        options: {
          redirectTo: redirectUrl,
          // 必須: email を含めないと Supabase auth.users.email が空になり、
          // pending-membership のメアド一致が失敗してorgに自動参加できない。
          // offline_access は refresh token のため。
          scopes: 'openid email profile offline_access',
        },
      })

      if (signInError) {
        setError(`ログインエラー: ${signInError.message}`)
        setLoading(false)
        return
      }

      if (data?.url) {
        window.location.href = data.url
      } else {
        setError('認証URLの取得に失敗しました。もう一度お試しください。')
        setLoading(false);
      }
    } catch (err: any) {
      setError(`ログインに失敗しました: ${err.message || '予期しないエラーが発生しました'}`);
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    try {
      setLoading(true);
      setError(null);

      // クライアント側で直接OAuthを開始（クッキーストレージを使用）
      const { createClient } = await import('@/utils/supabase/client')
      const supabase = createClient()
      
      // リダイレクトURLを構築（現在のoriginを使用）
      const redirectUrl = `${window.location.origin}/auth/callback?next=${encodeURIComponent(redirectTo)}`
      console.log('Starting Google OAuth with redirect:', redirectUrl)
      
      const { data, error: signInError } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: redirectUrl,
          queryParams: {
            access_type: 'offline',
            prompt: 'consent',
          },
        },
      })

      if (signInError) {
        console.error('OAuth error:', signInError)
        setError(`ログインエラー: ${signInError.message}`)
        setLoading(false)
        return
      }

      if (data?.url) {
        console.log('Redirecting to OAuth URL:', data.url.substring(0, 100) + '...')
        // OAuth URLにリダイレクト
        window.location.href = data.url
        // リダイレクト後はこのコードは実行されないが、念のため
      } else {
        console.error('No OAuth URL received')
        setError('認証URLの取得に失敗しました。もう一度お試しください。')
        setLoading(false)
      }
    } catch (err: any) {
      console.error("Login error:", err);
      setError(`ログインに失敗しました: ${err.message || '予期しないエラーが発生しました'}`);
      setLoading(false);
    }
  };

  const handleAppleLogin = async () => {
    console.log('🍎 Apple Sign In button clicked');
    try {
      setLoading(true);
      setError(null);
      console.log('🍎 Starting Apple OAuth flow...');

      // クライアント側で直接OAuthを開始（クッキーストレージを使用）
      const { createClient } = await import('@/utils/supabase/client')
      const supabase = createClient()
      console.log('🍎 Supabase client created');
      
      // リダイレクトURLを構築（現在のoriginを使用）
      const redirectUrl = `${window.location.origin}/auth/callback?next=${encodeURIComponent(redirectTo)}`
      console.log('🍎 Redirect URL:', redirectUrl)
      
      const { data, error: signInError } = await supabase.auth.signInWithOAuth({
        provider: 'apple',
        options: {
          redirectTo: redirectUrl,
        },
      })

      console.log('🍎 OAuth response:', { data, error: signInError });

      if (signInError) {
        console.error('🍎 OAuth error:', signInError)
        setError(`ログインエラー: ${signInError.message}`)
        setLoading(false);
        return
      }

      if (data?.url) {
        console.log('🍎 Redirecting to:', data.url.substring(0, 100) + '...');
        // OAuth URLにリダイレクト
        window.location.href = data.url
        // リダイレクト後はこのコードは実行されないが、念のため
      } else {
        console.error('🍎 No OAuth URL received');
        setError('認証URLの取得に失敗しました。もう一度お試しください。')
        setLoading(false);
      }
    } catch (err: any) {
      console.error("🍎 Login error:", err);
      setError(`ログインに失敗しました: ${err.message || '予期しないエラーが発生しました'}`);
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-white flex flex-col">
      {/* Header */}
      <header className="border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <Link href="/" className="text-2xl font-bold text-gray-900">
            lecsy
          </Link>
        </div>
      </header>

      {/* Login Content */}
      <div className="flex-1 flex items-center justify-center px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-2">Login</h1>
            <p className="text-gray-600">
              Sign in to access your lectures on the web
            </p>
          </div>

          {error && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-red-800 text-sm mb-2">{error}</p>
              <button
                onClick={() => {
                  setError(null)
                  // ページをリロードして再試行
                  window.location.reload()
                }}
                className="text-red-700 hover:text-red-900 text-sm underline"
              >
                もう一度お試しください
              </button>
            </div>
          )}

          <div className="space-y-4">
            {/* Microsoft Login — placed first so US college students whose
                school identity runs on Microsoft 365 / Entra ID land here
                immediately. Pre-registered .edu memberships auto-activate
                via PostLoginCoordinator once Supabase records the user. */}
            <button
              onClick={handleMicrosoftLogin}
              disabled={loading}
              className="w-full flex items-center justify-center gap-3 px-6 py-3 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="w-5 h-5" viewBox="0 0 23 23" xmlns="http://www.w3.org/2000/svg">
                <rect x="1" y="1" width="10" height="10" fill="#F25022" />
                <rect x="12" y="1" width="10" height="10" fill="#7FBA00" />
                <rect x="1" y="12" width="10" height="10" fill="#00A4EF" />
                <rect x="12" y="12" width="10" height="10" fill="#FFB900" />
              </svg>
              <span className="text-gray-700 font-medium">
                {loading ? "Loading..." : "Continue with Microsoft"}
              </span>
            </button>

            {/* Google Login */}
            <button
              onClick={handleGoogleLogin}
              disabled={loading}
              className="w-full flex items-center justify-center gap-3 px-6 py-3 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              <span className="text-gray-700 font-medium">
                {loading ? "Loading..." : "Continue with Google"}
              </span>
            </button>

            {/* Apple Login */}
            <button
              onClick={handleAppleLogin}
              disabled={loading}
              className="w-full flex items-center justify-center gap-3 px-6 py-3 bg-black text-white rounded-lg hover:bg-gray-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
              </svg>
              <span className="font-medium">
                {loading ? "Loading..." : "Continue with Apple"}
              </span>
            </button>
          </div>

          <p className="mt-6 text-sm text-gray-500 text-center">
            By continuing, you agree to our{" "}
            <Link href="/terms" className="text-blue-600 hover:text-blue-800 underline">
              Terms of Service
            </Link>{" "}
            and{" "}
            <Link href="/privacy" className="text-blue-600 hover:text-blue-800 underline">
              Privacy Policy
            </Link>
            .
          </p>
        </div>
      </div>
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={
      <main className="min-h-screen bg-white flex flex-col items-center justify-center">
        <div className="text-gray-600">Loading...</div>
      </main>
    }>
      <LoginForm />
    </Suspense>
  );
}
