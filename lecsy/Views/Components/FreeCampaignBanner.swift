//
//  FreeCampaignBanner.swift
//  lecsy
//
//  "5/31まで全機能無料開放" キャンペーンの告知バナー。
//
//  設計方針:
//   - 終了日 (CampaignConfig.endDate) は Edge Function
//     (supabase/functions/_shared/campaign.ts) と Web (web/utils/isPro.ts)
//     と必ず同じ値にする。片方だけズレると UI と実レートが食い違う。
//   - 6/1 を過ぎたら何もしなくても自動的に非表示になる。
//   - ユーザーが一度 ✕ で閉じたら UserDefaults に記録して再表示しない。
//

import SwiftUI

enum CampaignConfig {
    /// キャンペーン終了日時 (JST 2026-06-01 00:00)。
    /// Edge Function / Web と同期させること。
    static let endDate: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 1
        comps.hour = 0
        comps.minute = 0
        comps.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date.distantFuture
    }()

    static var isActive: Bool {
        Date() < endDate
    }

    /// 残り日数 (切り上げ)
    static var daysRemaining: Int {
        let secs = endDate.timeIntervalSinceNow
        guard secs > 0 else { return 0 }
        return Int(ceil(secs / 86400))
    }
}

/// Small, quiet trial-period indicator. Always visible while the campaign is
/// active — no dismiss button, no gradient, no emoji. Sits at the top of the
/// screen as a subtle pill so users remember the free window is finite without
/// feeling marketed at.
struct FreeCampaignBanner: View {
    var body: some View {
        if CampaignConfig.isActive {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .semibold))
                Text("Free trial until May 31")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .padding(.top, 4)
            .accessibilityLabel("Free trial until May 31")
        }
    }
}

