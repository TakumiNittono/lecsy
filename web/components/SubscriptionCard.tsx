'use client'

import UpgradeButton from './UpgradeButton'
import ManageSubscriptionButton from './ManageSubscriptionButton'

interface SubscriptionCardProps {
  status: string | null
  currentPeriodEnd: string | null
  cancelAtPeriodEnd: boolean | null
  isWhitelisted?: boolean
}

export default function SubscriptionCard({ status, currentPeriodEnd, cancelAtPeriodEnd, isWhitelisted = false }: SubscriptionCardProps) {
  const isPro = status === 'active'
  const willCancel = cancelAtPeriodEnd === true

  // 次回更新日のフォーマット
  const formatNextBillingDate = (dateString: string | null) => {
    if (!dateString) return null
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-gray-900">Subscription</h2>
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${
          isPro ? 'bg-gradient-to-r from-blue-500 to-purple-500' : 'bg-purple-100'
        }`}>
          <svg className={`w-6 h-6 ${isPro ? 'text-white' : 'text-purple-600'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
          </svg>
        </div>
      </div>
      
      {isPro ? (
        <>
          <div className="mb-4">
            <p className="text-lg font-semibold text-gray-900">Pro</p>
            <p className="text-sm text-gray-500 mt-1">
              {isWhitelisted ? 'Developer access' : 'Current plan'}
            </p>
            {isWhitelisted ? (
              <p className="text-xs text-blue-600 mt-2 font-medium">
                ✨ Complimentary access
              </p>
            ) : willCancel ? (
              <p className="text-xs text-orange-600 mt-2 font-medium">
                ⚠️ Cancels on {formatNextBillingDate(currentPeriodEnd)}
              </p>
            ) : currentPeriodEnd ? (
              <p className="text-xs text-gray-500 mt-2">
                Renews on {formatNextBillingDate(currentPeriodEnd)}
              </p>
            ) : null}
          </div>
          {!isWhitelisted && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <ManageSubscriptionButton className="w-full text-center justify-center" />
            </div>
          )}
        </>
      ) : (
        <>
          <div className="mb-4">
            <p className="text-lg font-semibold text-gray-900">Free</p>
            <p className="text-sm text-gray-500 mt-1">Current plan</p>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-200">
            <UpgradeButton className="w-full" />
          </div>
        </>
      )}
    </div>
  )
}
