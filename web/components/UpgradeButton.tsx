'use client'

// Legacy component kept as a no-op during the "Free Until June 1" campaign.
// All features (AI summary, exam mode, cloud sync) are open to every signed-in
// user. We intentionally render nothing here so any stale references in older
// pages don't show a broken "Upgrade to Pro" button that hits a 503 endpoint.
//
// When a paid plan launches after LLC setup, restore the original checkout
// button by reverting this file in git history.

interface UpgradeButtonProps {
  className?: string
  variant?: 'default' | 'outline' | 'ghost'
}

export default function UpgradeButton(_props: UpgradeButtonProps) {
  return null
}
