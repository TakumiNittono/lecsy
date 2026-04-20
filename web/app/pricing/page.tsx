// /pricing - Lecsy plan overview (B2B first, individual Pro in development)
// 参照: Deepgram/EXECUTION_PLAN.md W06
//
// 2026-06-01 ローンチ時点の想定:
//   - 個人向け Pro は iOS 内に課金導線なし (waitlist のみ)
//   - Organization プランは /schools から営業契約で提供
//   - ここの Paid プラン数字は目安 (final pricing TBD)

'use client'

import { useState } from 'react'
import Link from 'next/link'

type Plan = 'free' | 'student' | 'pro' | 'power'
type PaidPlan = 'student' | 'pro' | 'power'
type Cycle = 'monthly' | 'yearly'

interface PriceCard {
  plan: Plan
  name: string
  emoji: string
  monthlyUSD: number
  yearlyUSD: number
  tagline: string
  features: string[]
  highlight?: boolean
  isFree?: boolean
}

const PLANS: PriceCard[] = [
  {
    plan: 'free',
    name: 'Free',
    emoji: '🌱',
    monthlyUSD: 0,
    yearlyUSD: 0,
    tagline: 'Try before you buy',
    features: [
      'English live captions — 2 h / month',
      'Record lectures (no limit)',
      'AI Study Guide — 3 / month (Quick)',
      'Transcript sync across devices',
    ],
    isFree: true,
  },
  {
    plan: 'student',
    name: 'Student',
    emoji: '🎓',
    monthlyUSD: 7.99,
    yearlyUSD: 69,
    tagline: 'For typical undergrads',
    features: [
      'Live bilingual captions — 10 h / month',
      'Unlimited AI Study Guide',
      'Unlimited Anki / Quizlet export',
      '.edu email required',
    ],
  },
  {
    plan: 'pro',
    name: 'Pro',
    emoji: '⚡',
    monthlyUSD: 12.99,
    yearlyUSD: 109,
    tagline: 'For graduate and heavy users',
    features: [
      'Live bilingual captions — 15 h / month',
      'Unlimited AI Study Guide',
      'Unlimited Anki / Quizlet export',
      'Unlimited Exam Prep Plan',
    ],
    highlight: true,
  },
  {
    plan: 'power',
    name: 'Power',
    emoji: '🚀',
    monthlyUSD: 24.99,
    yearlyUSD: 229,
    tagline: 'For PhD and researchers',
    features: [
      'Live bilingual captions — 30 h / month',
      'Priority queue for AI features',
      'Unlimited everything',
      '24h priority support + monthly coaching call',
    ],
  },
]

export default function PricingPage() {
  const [cycle, setCycle] = useState<Cycle>('monthly')
  const [loading, setLoading] = useState<Plan | null>(null)
  const [error, setError] = useState<string | null>(null)
  const campaignActive = false

  async function startCheckout(plan: PaidPlan) {
    setError(null)
    setLoading(plan)
    try {
      const res = await fetch('/api/stripe/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plan, cycle }),
      })
      const json = await res.json()
      if (!res.ok || !json.url) {
        if (res.status === 401) {
          window.location.href = `/login?redirectTo=${encodeURIComponent('/pricing')}`
          return
        }
        setError(json.error || 'Failed to start checkout')
        return
      }
      window.location.href = json.url
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Network error')
    } finally {
      setLoading(null)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-white to-gray-50 px-6 py-16">
      <div className="mx-auto max-w-5xl">
        <header className="text-center">
          <h1 className="text-4xl font-extrabold tracking-tight text-gray-900 sm:text-5xl">
            Choose your plan
          </h1>
          <p className="mt-4 text-lg text-gray-700">
            Lecsy is the only iOS app built for international students attending English-language lectures.
          </p>

          <div className="mx-auto mt-6 max-w-2xl rounded-xl bg-gradient-to-r from-indigo-50 to-blue-50 px-5 py-3 ring-1 ring-indigo-200">
            <p className="text-sm font-semibold text-indigo-900">
              🌱 The <strong>Free</strong> plan (on-device transcription) is available today on the App Store.
            </p>
            <p className="mt-2 text-sm text-indigo-900">
              🏫 For schools &amp; universities, Organization plans are available under a separate pilot or license agreement &mdash;{' '}
              <Link href="/schools" className="font-semibold text-indigo-700 hover:text-indigo-900 underline">
                see the schools page
              </Link>
              .
            </p>
            <p className="mt-2 text-xs text-indigo-700">
              Individual Student / Pro / Power tiers shown below are in development. No in-app purchase path at this time &mdash;{' '}
              <a href="mailto:support@lecsy.app?subject=Lecsy%20Beta%20Waitlist" className="text-indigo-700 hover:text-indigo-900 underline">
                join the waitlist
              </a>{' '}
              to be notified.
            </p>
          </div>

          <div className="mt-8 inline-flex rounded-full bg-gray-100 p-1">
            <button
              onClick={() => setCycle('monthly')}
              className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
                cycle === 'monthly' ? 'bg-white text-gray-900 shadow' : 'text-gray-900'
              }`}
            >
              Monthly
            </button>
            <button
              onClick={() => setCycle('yearly')}
              className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
                cycle === 'yearly' ? 'bg-white text-gray-900 shadow' : 'text-gray-900'
              }`}
            >
              Yearly{' '}
              <span className="ml-1 rounded-full bg-green-100 px-2 py-0.5 text-xs text-green-800">
                -30%
              </span>
            </button>
          </div>
        </header>

        {error && (
          <div className="mx-auto mt-6 max-w-md rounded-lg bg-red-50 p-3 text-sm text-red-800 ring-1 ring-red-200">
            {error}
          </div>
        )}

        <div className="mt-12 grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {PLANS.map((p) => {
            const price = cycle === 'monthly' ? p.monthlyUSD : p.yearlyUSD
            const unit = cycle === 'monthly' ? '/month' : '/year'
            return (
              <article
                key={p.plan}
                className={`relative rounded-2xl p-8 ring-1 ${
                  p.isFree
                    ? 'bg-white ring-blue-500'
                    : 'bg-gray-50 ring-gray-200 opacity-90'
                }`}
              >
                {!p.isFree && (
                  <div className="absolute right-6 top-6 rounded-full bg-gradient-to-r from-indigo-600 to-blue-600 px-3 py-1 text-xs font-bold text-white">
                    SOON
                  </div>
                )}
                {p.isFree && (
                  <div className="absolute right-6 top-6 rounded-full bg-blue-600 px-3 py-1 text-xs font-bold text-white">
                    AVAILABLE
                  </div>
                )}
                <div className="text-3xl">{p.emoji}</div>
                <h2 className="mt-3 text-xl font-bold text-gray-900">{p.name}</h2>
                <p className="mt-1 text-xs text-gray-600">{p.tagline}</p>
                <div className="mt-4 flex items-baseline gap-1">
                  {p.isFree ? (
                    <>
                      <span className="text-4xl font-extrabold text-gray-900">$0</span>
                      <span className="text-gray-700">forever</span>
                    </>
                  ) : (
                    <>
                      <span className="text-4xl font-extrabold text-gray-900">${price}</span>
                      <span className="text-gray-700">{unit}</span>
                    </>
                  )}
                </div>
                <ul className="mt-6 space-y-2 text-sm text-gray-900">
                  {p.features.map((f) => (
                    <li key={f} className="flex items-start gap-2">
                      <span className="mt-0.5 text-blue-600">✓</span>
                      <span>{f}</span>
                    </li>
                  ))}
                </ul>
                {p.isFree ? (
                  <Link
                    href="/app"
                    className="mt-8 block w-full rounded-lg bg-blue-600 px-4 py-3 text-center text-sm font-semibold text-white hover:bg-blue-700 transition"
                  >
                    Start Free
                  </Link>
                ) : (
                  <a
                    href={`mailto:support@lecsy.app?subject=Lecsy%20Beta%20Waitlist%20-%20${p.name}`}
                    className="mt-8 block w-full rounded-lg bg-gradient-to-r from-indigo-600 to-blue-600 px-4 py-3 text-center text-sm font-semibold text-white hover:opacity-90 transition"
                  >
                    Notify me
                  </a>
                )}
              </article>
            )
          })}
        </div>

        <footer className="mt-12 text-center text-sm text-gray-700">
          <p>
            Cancel anytime via{' '}
            <Link href="/app" className="font-semibold text-blue-600 hover:underline">
              your account
            </Link>
            . All payments processed securely by Stripe.
          </p>
          <p className="mt-2">
            Need an organization plan?{' '}
            <a href="mailto:support@lecsy.app" className="font-semibold text-blue-600 hover:underline">
              Contact us
            </a>
            .
          </p>
        </footer>
      </div>
    </div>
  )
}
