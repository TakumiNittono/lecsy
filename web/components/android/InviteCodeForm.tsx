"use client"

import { useEffect, useState } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { createClient } from "@/utils/supabase/client"

type RedeemResult = {
  ok?: boolean
  error?: string
  org_id?: string
  role?: string
  label?: string
}

export function InviteCodeForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  // Invite codes are 6 digits (numeric migration 2026-04-21). We still
  // accept alphanumeric chars in normalization in case a legacy card is
  // scanned, but the UI keypad is digits-only.
  const initialCode = (searchParams.get("code") || "")
    .replace(/\D/g, "")
    .slice(0, 6)

  const [code, setCode] = useState(initialCode)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [autoSubmitted, setAutoSubmitted] = useState(false)

  const submit = async (raw: string) => {
    setError(null)
    const normalized = raw.trim().replace(/\D/g, "")
    if (normalized.length !== 6) {
      setError("Please enter the 6-digit code on your card.")
      return
    }
    setLoading(true)
    try {
      const supabase = createClient()
      const { error: anonError } = await supabase.auth.signInAnonymously()
      if (anonError) {
        setError(`Couldn't start a session: ${anonError.message}`)
        return
      }
      const { data, error: rpcError } = await supabase.rpc("redeem_invite_code", {
        p_code: normalized,
      })
      if (rpcError) {
        await supabase.auth.signOut()
        setError(`Invite code error: ${rpcError.message}`)
        return
      }
      const result = (data ?? {}) as RedeemResult
      if (result.error) {
        await supabase.auth.signOut()
        const friendly =
          result.error === "code_not_found"
            ? "We couldn't find that code. Double-check the digits."
            : result.error === "code_already_used"
            ? "This code has already been used. Ask your teacher for a new one."
            : result.error === "code_expired"
            ? "This code has expired."
            : result.error === "rate_limited"
            ? "Too many tries. Please wait a minute and try again."
            : `Invite code error: ${result.error}`
        setError(friendly)
        return
      }
      if (result.ok !== true) {
        await supabase.auth.signOut()
        setError("Could not redeem invite code. Please try again.")
        return
      }
      router.replace("/android/app")
    } catch (e: any) {
      setError(`Invite code failed: ${e?.message || "unexpected error"}`)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (initialCode.length === 6 && !autoSubmitted) {
      setAutoSubmitted(true)
      void submit(initialCode)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialCode, autoSubmitted])

  return (
    <div className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4">
        <h2 className="font-semibold text-gray-900 text-[15px]">Have an invite code?</h2>
        <p className="mt-1 text-[13px] text-gray-500 leading-relaxed">
          Enter the 6-digit code your teacher gave you.
        </p>
      </div>
      <input
        type="text"
        inputMode="numeric"
        pattern="[0-9]*"
        autoComplete="one-time-code"
        autoCorrect="off"
        spellCheck={false}
        placeholder="000000"
        value={code}
        onChange={(e) =>
          setCode(e.target.value.replace(/\D/g, "").slice(0, 6))
        }
        onKeyDown={(e) => {
          if (e.key === "Enter" && code.length === 6 && !loading) submit(code)
        }}
        disabled={loading}
        autoFocus
        aria-label="6-digit invite code"
        className="w-full h-16 rounded-2xl border border-gray-200 bg-gray-50 text-gray-900 text-[28px] font-semibold font-mono tracking-[0.45em] text-center placeholder:text-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent focus:bg-white transition disabled:opacity-50"
      />
      <button
        onClick={() => submit(code)}
        disabled={loading || code.length !== 6}
        className="mt-4 w-full h-12 rounded-full bg-gray-900 text-white text-[15px] font-medium hover:bg-gray-800 active:bg-black transition-colors disabled:opacity-40 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
      >
        {loading ? (
          <span className="inline-flex items-center gap-2">
            <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Joining…
          </span>
        ) : (
          <>Join class</>
        )}
      </button>
      {error && (
        <div className="mt-4 p-3.5 rounded-2xl bg-red-50 border border-red-100">
          <p className="text-red-700 text-[13.5px] leading-relaxed">{error}</p>
        </div>
      )}
    </div>
  )
}
