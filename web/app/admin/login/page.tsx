"use client";

import Link from "next/link";
import { Suspense, useEffect, useState } from "react";

// Personal admin sign-in for the super-admin (nittonotakumi@gmail.com).
// /login is locked to invite-code only for the B2B classroom pilot, so this
// is the only web entry point left for the operator console at /admin.
// Non-super-admins who land here and sign in will hit /admin's own
// isSuperAdmin gate and get bounced to /app — there is no privilege
// escalation here, this page is just the front door.

function AdminLoginForm() {
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [emailInput, setEmailInput] = useState("");
  const [otpCodeInput, setOtpCodeInput] = useState("");
  const [stage, setStage] = useState<"email" | "code">("email");

  const next = "/admin";

  const handleGoogleLogin = async () => {
    try {
      setLoading(true);
      setError(null);
      const { createClient } = await import("@/utils/supabase/client");
      const supabase = createClient();
      const redirectUrl = `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;
      const { data, error: signInError } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: redirectUrl,
          queryParams: {
            access_type: "offline",
            prompt: "consent",
          },
        },
      });
      if (signInError) {
        setError(`Sign-in error: ${signInError.message}`);
        setLoading(false);
        return;
      }
      if (data?.url) {
        window.location.href = data.url;
      } else {
        setError("Couldn't start sign-in. Please try again.");
        setLoading(false);
      }
    } catch (err: any) {
      setError(`Sign-in failed: ${err?.message || "unexpected error"}`);
      setLoading(false);
    }
  };

  const handleSendCode = async () => {
    setError(null);
    const email = emailInput.trim();
    if (!email) {
      setError("Please enter your email address.");
      return;
    }
    try {
      setLoading(true);
      const { createClient } = await import("@/utils/supabase/client");
      const supabase = createClient();
      const { error: otpError } = await supabase.auth.signInWithOtp({
        email,
        options: {
          shouldCreateUser: false,
          emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`,
        },
      });
      if (otpError) {
        setError(`We couldn't send the code: ${otpError.message}`);
        return;
      }
      setStage("code");
      setOtpCodeInput("");
    } catch (err: any) {
      setError(`We couldn't send the code: ${err?.message || "unexpected error"}`);
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyCode = async (codeOverride?: string) => {
    setError(null);
    const email = emailInput.trim();
    const token = (codeOverride ?? otpCodeInput).trim();
    if (token.length !== 6) {
      setError("Please enter the 6-digit code.");
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
        setError(`That code didn't match: ${verifyError?.message || "please try again"}`);
        return;
      }
      window.location.href = next;
    } catch (err: any) {
      setError(`Sign-in failed: ${err?.message || "unexpected error"}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (stage === "code") {
      const digits = otpCodeInput.replace(/\D/g, "");
      if (digits.length >= 6) {
        const code = digits.slice(0, 6);
        if (code !== otpCodeInput) setOtpCodeInput(code);
        handleVerifyCode(code);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [otpCodeInput, stage]);

  return (
    <main className="min-h-screen bg-white flex flex-col">
      <header className="border-b border-gray-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5">
          <Link href="/" className="text-xl font-semibold tracking-tight text-gray-900">
            lecsy
          </Link>
        </div>
      </header>

      <div className="flex-1 flex items-center justify-center px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
        <div className="max-w-sm w-full">
          <div className="text-center mb-10">
            <h1 className="text-3xl sm:text-4xl font-semibold tracking-tight text-gray-900 mb-3">
              Operator sign-in
            </h1>
            <p className="text-gray-500 text-[15px] leading-relaxed">
              Restricted to lecsy operators. Sign in to reach the admin console.
            </p>
          </div>

          {error && (
            <div className="mb-5 p-4 bg-red-50 border border-red-100 rounded-2xl">
              <p className="text-red-700 text-sm leading-relaxed">{error}</p>
            </div>
          )}

          <div className="space-y-4">
            <button
              onClick={handleGoogleLogin}
              disabled={loading}
              className="w-full flex items-center justify-center gap-3 h-12 rounded-full border border-gray-200 bg-white text-gray-900 text-[15px] font-medium hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24" aria-hidden>
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
              </svg>
              {loading ? "Loading…" : "Continue with Google"}
            </button>
          </div>

          <div className="flex items-center gap-3 my-6 text-xs text-gray-400 uppercase tracking-wider">
            <span className="flex-1 h-px bg-gray-200" />
            or
            <span className="flex-1 h-px bg-gray-200" />
          </div>

          <div className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
            {stage === "email" ? (
              <>
                <div className="mb-4">
                  <h2 className="font-semibold text-gray-900 text-[15px]">
                    Email a 6-digit code
                  </h2>
                  <p className="mt-1 text-[13px] text-gray-500 leading-relaxed">
                    We&apos;ll only send a code to a registered operator email.
                  </p>
                </div>
                <input
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  autoCapitalize="none"
                  autoCorrect="off"
                  spellCheck={false}
                  placeholder="you@example.com"
                  value={emailInput}
                  onChange={(e) => setEmailInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && emailInput.trim() && !loading) {
                      handleSendCode();
                    }
                  }}
                  disabled={loading}
                  className="w-full h-12 px-4 rounded-2xl border border-gray-200 bg-gray-50 text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent focus:bg-white transition disabled:opacity-50"
                />
                <button
                  onClick={handleSendCode}
                  disabled={loading || !emailInput.trim()}
                  className="mt-4 w-full h-12 rounded-full bg-gray-900 text-white text-[15px] font-medium hover:bg-gray-800 active:bg-black transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  {loading ? "Sending…" : "Send code"}
                </button>
              </>
            ) : (
              <>
                <div className="mb-4 text-center">
                  <div className="text-xs text-gray-500 mb-0.5">We sent a 6-digit code to</div>
                  <div className="text-sm font-semibold text-gray-900 break-all">{emailInput}</div>
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
                  className="w-full h-16 rounded-2xl border border-gray-200 bg-gray-50 text-gray-900 text-[28px] font-semibold font-mono tracking-[0.45em] text-center focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent focus:bg-white transition disabled:opacity-50"
                />
                <div className="mt-4 flex items-center justify-between text-xs">
                  <button
                    type="button"
                    onClick={() => {
                      setStage("email");
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
                    onClick={handleSendCode}
                    disabled={loading}
                    className="text-gray-900 hover:text-black font-medium disabled:opacity-50"
                  >
                    Resend code
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </main>
  );
}

export default function AdminLoginPage() {
  return (
    <Suspense fallback={
      <main className="min-h-screen bg-white flex flex-col items-center justify-center">
        <div className="text-gray-600">Loading…</div>
      </main>
    }>
      <AdminLoginForm />
    </Suspense>
  );
}
