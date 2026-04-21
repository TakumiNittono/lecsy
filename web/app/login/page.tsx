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

  // Magic Link (email OTP) — primary sign-in path for education customers.
  // Santa Fe / FMCC / ESL schools on Microsoft 365 block OAuth consent by
  // policy, so we front-load the email-code flow: enter .edu address →
  // 6-digit code in Outlook → verify → /app.
  const [emailInput, setEmailInput] = useState("");
  const [otpCodeInput, setOtpCodeInput] = useState("");
  const [magicLinkStage, setMagicLinkStage] = useState<"email" | "code">("email");

  // Invite code (classroom pilot) — bypasses email entirely. Teacher hands
  // out a 6-char code on paper / QR; student types it → we do
  // signInAnonymously() + redeem_invite_code RPC. See
  // supabase/migrations/20260420000000_invite_codes.sql for the backend.
  const [inviteCodeInput, setInviteCodeInput] = useState("");

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

  const handleJoinWithInviteCode = async () => {
    setError(null);
    const normalized = inviteCodeInput
      .trim()
      .replace(/[\s-]/g, "")
      .toUpperCase();
    if (normalized.length < 4) {
      setError("Please enter the 6-character code on your card.");
      return;
    }
    try {
      setLoading(true);
      const { createClient } = await import("@/utils/supabase/client");
      const supabase = createClient();

      // 1. Anonymous sign-in so the RPC call is authenticated.
      const { error: anonError } = await supabase.auth.signInAnonymously();
      if (anonError) {
        setError(`Couldn't start a session: ${anonError.message}`);
        setLoading(false);
        return;
      }

      // 2. Redeem the code. The RPC attaches the anon user to the org.
      const { data, error: rpcError } = await supabase.rpc("redeem_invite_code", {
        p_code: normalized,
      });
      if (rpcError) {
        // Clean up anonymous session to avoid zombie accounts.
        await supabase.auth.signOut();
        setError(`Invite code error: ${rpcError.message}`);
        setLoading(false);
        return;
      }
      const result = (data ?? {}) as {
        ok?: boolean;
        error?: string;
        org_id?: string;
        role?: string;
        label?: string;
      };
      if (result.error) {
        await supabase.auth.signOut();
        const userMsg =
          result.error === "code_not_found"
            ? "We couldn't find that code. Double-check the letters."
            : result.error === "code_already_used"
            ? "This code has already been used. Ask your teacher for a new one."
            : result.error === "code_expired"
            ? "This code has expired."
            : `Invite code error: ${result.error}`;
        setError(userMsg);
        setLoading(false);
        return;
      }
      if (result.ok !== true) {
        await supabase.auth.signOut();
        setError("Could not redeem invite code. Please try again.");
        setLoading(false);
        return;
      }
      // Success — org_id is in result.org_id. Navigate straight to that
      // org's dashboard if they're staff; otherwise the generic /app.
      if (result.role && result.role !== "student" && result.org_id) {
        // We don't have the slug here, so fall back to /app which the
        // layout will route into the right org automatically.
      }
      window.location.href = redirectTo;
    } catch (err: any) {
      setError(`Invite code failed: ${err?.message || "unexpected error"}`);
      setLoading(false);
    }
  };

  const handleSendMagicLink = async () => {
    setError(null);
    const email = emailInput.trim();
    if (!email) {
      setError("メールアドレスを入力してください");
      return;
    }
    try {
      setLoading(true);
      const { createClient } = await import("@/utils/supabase/client");
      const supabase = createClient();
      const { error: otpError } = await supabase.auth.signInWithOtp({
        email,
        options: {
          // .edu の初回サインインも許容 (pending-membership は後から activate)
          shouldCreateUser: true,
          emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(redirectTo)}`,
        },
      });
      if (otpError) {
        setError(`コード送信に失敗しました: ${otpError.message}`);
        return;
      }
      setMagicLinkStage("code");
      setOtpCodeInput("");
    } catch (err: any) {
      setError(`コード送信に失敗しました: ${err?.message || "予期しないエラー"}`);
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (codeOverride?: string) => {
    setError(null);
    const email = emailInput.trim();
    const token = (codeOverride ?? otpCodeInput).trim();
    if (token.length !== 6) {
      setError("6桁のコードを入力してください");
      return;
    }
    try {
      setLoading(true);
      const { createClient } = await import("@/utils/supabase/client");
      const supabase = createClient();
      const { data, error: verifyError } = await supabase.auth.verifyOtp({
        email,
        token,
        type: "email",
      });
      if (verifyError || !data.session) {
        setError(`コードが一致しません: ${verifyError?.message || "もう一度お試しください"}`);
        return;
      }
      // セッション Cookie が書かれた状態で /app (or redirectTo) に遷移。
      window.location.href = redirectTo;
    } catch (err: any) {
      setError(`認証に失敗しました: ${err?.message || "予期しないエラー"}`);
    } finally {
      setLoading(false);
    }
  };

  // 6桁入ったら自動確定 (iOS LoginView と同じ UX)
  useEffect(() => {
    if (magicLinkStage === "code") {
      const digits = otpCodeInput.replace(/\D/g, "");
      if (digits.length >= 6) {
        const code = digits.slice(0, 6);
        if (code !== otpCodeInput) setOtpCodeInput(code);
        handleVerifyOtp(code);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [otpCodeInput, magicLinkStage]);

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
            <h1 className="text-3xl font-bold text-gray-900 mb-2">Join your class</h1>
            <p className="text-gray-600">
              Web access is invite-only while we&apos;re in classroom pilot.
              Personal users, please use the iOS app.
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

          {/*
            Microsoft (Entra ID) ボタンは一時非表示。US 大学 / コミカレ
            (Santa Fe College, FMCC 等) の Entra ID テナントは「未検証
            multitenant アプリへの end-user consent をブロック」がデフォルト。
            学生が押しても admin 承認要求画面に飛ぶ。本契約フェーズで各校 IT
            から admin consent をもらうか、Microsoft Verified Publisher 化
            してから再表示する。handleMicrosoftLogin / signInWithOAuth 実装
            は残すので、このフラグを外すだけで復活できる。
          */}

          {/* ── Primary: Invite code (classroom pilot) ── */}
          <div className="rounded-2xl border-2 border-blue-600 bg-blue-50/40 p-5 mb-5">
            <div className="flex items-center gap-2 mb-1">
              <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" />
              </svg>
              <h2 className="font-semibold text-gray-900 text-base">
                Have an invite code?
              </h2>
            </div>
            <p className="text-xs text-gray-600 mb-3">
              Type the 6-character code your teacher handed you.
            </p>
            <input
              type="text"
              inputMode="text"
              autoComplete="one-time-code"
              autoCapitalize="characters"
              autoCorrect="off"
              spellCheck={false}
              placeholder="XXXXXX"
              value={inviteCodeInput}
              onChange={(e) =>
                setInviteCodeInput(
                  e.target.value.replace(/[\s-]/g, "").toUpperCase().slice(0, 12)
                )
              }
              onKeyDown={(e) => {
                if (e.key === "Enter" && inviteCodeInput.length >= 4 && !loading) {
                  handleJoinWithInviteCode();
                }
              }}
              disabled={loading}
              className="w-full h-14 rounded-lg border border-gray-300 bg-white text-gray-900 text-2xl font-mono tracking-[0.5em] text-center uppercase focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
            />
            <button
              onClick={handleJoinWithInviteCode}
              disabled={loading || inviteCodeInput.length < 4}
              className="mt-3 w-full h-12 rounded-lg bg-blue-600 text-white font-semibold text-sm hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
              {loading ? "Joining..." : "Join class"}
            </button>
          </div>

          {/*
            Web B2C 動線は 2026-04-21 時点で全て非表示。Web は B2B 招待コード
            パイロット専用とし、個人ユーザーは iOS アプリへ誘導する。
            Magic Link / Google / Apple / Microsoft のハンドラと state は
            残すので、B2C を再開する時は JSX コメントを外すだけで復活可能。
          */}
          {false && (
          <>
          <div className="rounded-2xl border border-gray-200 bg-white p-5 mb-5">
            {magicLinkStage === "email" ? (
              <>
                <div className="mb-3">
                  <h2 className="font-semibold text-gray-900 text-base mb-1">
                    Sign in with your school email
                  </h2>
                  <p className="text-xs text-gray-600">
                    We&apos;ll email you a 6-digit code — works with any @*.edu address.
                  </p>
                </div>
                <input
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  autoCapitalize="none"
                  autoCorrect="off"
                  spellCheck={false}
                  placeholder="you@school.edu"
                  value={emailInput}
                  onChange={(e) => setEmailInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && emailInput.trim() && !loading) {
                      handleSendMagicLink();
                    }
                  }}
                  disabled={loading}
                  className="w-full h-12 px-4 rounded-lg border border-gray-300 bg-white text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
                />
                <button
                  onClick={handleSendMagicLink}
                  disabled={loading || !emailInput.trim()}
                  className="mt-3 w-full h-12 rounded-lg bg-blue-600 text-white font-semibold text-sm hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                  {loading ? "Sending..." : "Send code to email"}
                </button>
              </>
            ) : (
              <>
                <div className="mb-3 text-center">
                  <div className="text-xs text-gray-500 mb-0.5">We sent a 6-digit code to</div>
                  <div className="text-sm font-semibold text-gray-900 break-all">{emailInput}</div>
                  <div className="text-xs text-gray-500 mt-2">
                    Check your inbox and junk folder. Delivery usually takes 10–60 seconds.
                  </div>
                </div>
                <input
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  pattern="[0-9]*"
                  maxLength={6}
                  placeholder="000000"
                  value={otpCodeInput}
                  onChange={(e) => setOtpCodeInput(e.target.value.replace(/\D/g, "").slice(0, 6))}
                  disabled={loading}
                  autoFocus
                  className="w-full h-14 rounded-lg border border-gray-300 bg-white text-gray-900 text-2xl font-mono tracking-[0.5em] text-center focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
                />
                <div className="mt-3 flex items-center justify-between text-xs">
                  <button
                    type="button"
                    onClick={() => {
                      setMagicLinkStage("email");
                      setOtpCodeInput("");
                      setError(null);
                    }}
                    disabled={loading}
                    className="text-gray-600 hover:text-gray-900 underline disabled:opacity-50"
                  >
                    Use a different email
                  </button>
                  <button
                    type="button"
                    onClick={handleSendMagicLink}
                    disabled={loading}
                    className="text-blue-600 hover:text-blue-800 font-medium disabled:opacity-50"
                  >
                    Resend code
                  </button>
                </div>
              </>
            )}
          </div>

          {/* ── Divider ── */}
          <div className="flex items-center gap-3 my-4 text-xs text-gray-400 uppercase tracking-wider">
            <span className="flex-1 h-px bg-gray-200" />
            or
            <span className="flex-1 h-px bg-gray-200" />
          </div>

          <div className="space-y-4">
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
          </>
          )}

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
