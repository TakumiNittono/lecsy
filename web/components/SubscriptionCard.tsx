'use client'

// "Free Until June 1" campaign card.
// All features are unlocked for every signed-in user until the LLC/Pro launch.
// Paid-plan props are accepted for backwards compatibility but ignored.

interface SubscriptionCardProps {
  status?: string | null
  currentPeriodEnd?: string | null
  cancelAtPeriodEnd?: boolean | null
  isWhitelisted?: boolean
  orgName?: string
}

export default function SubscriptionCard(_props: SubscriptionCardProps) {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-gray-900">Your Plan</h2>
        <div className="w-10 h-10 rounded-lg flex items-center justify-center bg-gradient-to-r from-green-500 to-emerald-500">
          <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
        </div>
      </div>

      <div className="mb-4">
        <p className="text-lg font-semibold text-gray-900">Free — Everything Unlocked</p>
        <p className="text-sm text-gray-500 mt-1">
          Recording, transcription, AI summary, and exam prep — all free.
        </p>
        <p className="text-xs text-green-700 mt-3 font-medium">
          ✨ Free for every user until June 1, 2026. No credit card, no ads.
        </p>
      </div>
    </div>
  )
}
