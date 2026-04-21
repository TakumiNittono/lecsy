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
  const initialCode = (searchParams.get("code") || "")
    .replace(/[\s-]/g, "")
    .toUpperCase()
    .slice(0, 12)

  const [code, setCode] = useState(initialCode)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [autoSubmitted, setAutoSubmitted] = useState(false)

  const submit = async (raw: string) => {
    setError(null)
    const normalized = raw.trim().replace(/[\s-]/g, "").toUpperCase()
    if (normalized.length < 4) {
      setError("Please enter the 6-character code on your card.")
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
            ? "We couldn't find that code. Double-check the letters."
            : result.error === "code_already_used"
            ? "This code has already been used. Ask your teacher for a new one."
            : result.error === "code_expired"
            ? "This code has expired."
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
    if (initialCode.length >= 4 && !autoSubmitted) {
      setAutoSubmitted(true)
      void submit(initialCode)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialCode, autoSubmitted])

  return (
    <div className="rounded-2xl border-2 border-blue-600 bg-blue-50/40 p-5">
      <div className="flex items-center gap-2 mb-1">
        <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" />
        </svg>
        <h2 className="font-semibold text-gray-900 text-base">Have an invite code?</h2>
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
        value={code}
        onChange={(e) =>
          setCode(e.target.value.replace(/[\s-]/g, "").toUpperCase().slice(0, 12))
        }
        onKeyDown={(e) => {
          if (e.key === "Enter" && code.length >= 4 && !loading) submit(code)
        }}
        disabled={loading}
        autoFocus
        className="w-full h-14 rounded-lg border border-gray-300 bg-white text-gray-900 text-2xl font-mono tracking-[0.5em] text-center uppercase focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
      />
      <button
        onClick={() => submit(code)}
        disabled={loading || code.length < 4}
        className="mt-3 w-full h-12 rounded-lg bg-blue-600 text-white font-semibold text-sm hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
        </svg>
        {loading ? "Joining..." : "Join class"}
      </button>
      {error && (
        <div className="mt-4 p-3 rounded-lg bg-red-50 border border-red-200">
          <p className="text-red-800 text-sm">{error}</p>
        </div>
      )}
    </div>
  )
}
