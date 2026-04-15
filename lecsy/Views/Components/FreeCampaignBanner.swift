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

    /// memo.md フェーズ1以降: キャンペーン撤廃。常に false。
    /// endDate / daysRemaining はレガシー互換のため残すが非表示になる。
    static var isActive: Bool { false }

    /// 残り日数 (切り上げ)
    static var daysRemaining: Int {
        let secs = endDate.timeIntervalSinceNow
        guard secs > 0 else { return 0 }
        return Int(ceil(secs / 86400))
    }
}

/// キャンペーン終了後は `CampaignConfig.isActive` が常に false なので何も表示しない。
/// 将来キャンペーンを再開する時のためにビュー構造だけ残している。
struct FreeCampaignBanner: View {
    var body: some View {
        EmptyView()
    }
}

