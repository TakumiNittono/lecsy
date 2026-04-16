//
//  PlanService.swift
//  lecsy
//
//  2026-06-01 B2B + B2C 同時ローンチ。Pro 判定ソースは2系統:
//    A. B2B: active な organization_members かつ org.plan='pro'
//    B. B2C: subscriptions.status='active' かつ provider='stripe'
//    どちらか一方でも満たせば Pro。両方とも無ければ Free。
//    Force local transcription ON → Pro でも WhisperKit を使う（QA用）
//
//  耐障害性:
//    - 一度 Pro と判定したプランを UserDefaults にキャッシュ、次回起動時に即復元
//    - refresh 中の一時的な失敗（JWT期限切れ、ネットワーク断、初期化レース）では Pro を降格しない
//    - 降格は「認証状態が完全に揃った上で、両方の経路で明示的に pro でないと確認できた」時のみ
//    - Task 直列化 + cancellation チェックで in-flight response の後着による書き戻しを防ぐ
//

import Foundation
import Combine
import UIKit

@MainActor
final class PlanService: ObservableObject {

    static let shared = PlanService()

    enum Plan: String {
        case free, pro
    }

    /// Pro の出所。UI で "via your organization" / "via Stripe subscription" を出し分けるため。
    enum ProSource: String {
        case none          // Free
        case organization  // B2B: active org member, org.plan='pro'
        case stripe        // B2C: subscriptions.status='active', provider='stripe'
    }

    static let forceLocalKey = "lecsy.forceLocalTranscription"
    private static let cachedPlanKey = "lecsy.cachedPlan"
    private static let cachedSourceKey = "lecsy.cachedProSource"

    @Published private(set) var currentPlan: Plan = .free
    @Published private(set) var proSource: ProSource = .none
    @Published private(set) var lastRefreshed: Date?

    /// B2C Stripe Checkout / Portal の UI をアプリ内で露出するかどうか。
    /// 2026-06-01 ローンチ時点では false。個人プラン解放タイミングで
    /// `update public.feature_flags set enabled=true where name='b2c_stripe_checkout'` で有効化。
    @Published private(set) var b2cCheckoutEnabled: Bool = false

    private var cancellables: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.cachedPlanKey),
           let cached = Plan(rawValue: raw) {
            currentPlan = cached
        }
        if let raw = UserDefaults.standard.string(forKey: Self.cachedSourceKey),
           let cached = ProSource(rawValue: raw) {
            proSource = cached
        }

        AuthService.shared.$currentUser
            .removeDuplicates(by: { $0?.id == $1?.id })
            .sink { [weak self] user in
                Task { @MainActor [weak self] in
                    if user == nil {
                        self?.clearPlan()
                    } else {
                        await self?.refresh()
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

    var isPaid: Bool {
        if forceLocalTranscription { return false }
        guard AuthService.shared.isAuthenticated else { return false }
        return currentPlan == .pro
    }

    var forceLocalTranscription: Bool {
        UserDefaults.standard.bool(forKey: Self.forceLocalKey)
    }

    func refresh() async {
        // サインイン直後は AuthService の currentUser sink と
        // RecordView.onAppear の両方から連続で呼ばれるので、1 秒以内の
        // 連打は前回の結果を流用する。重複ネットワーク + 重複ログを抑える。
        if let last = lastRefreshed, Date().timeIntervalSince(last) < 1.0 {
            return
        }
        refreshTask?.cancel()
        let task = Task { @MainActor in
            await performRefresh()
        }
        refreshTask = task
        await task.value
    }

    private func performRefresh() async {
        // 認証が揃っていない段階で呼ばれた場合はキャッシュを潰さない（起動レース対策）
        guard AuthService.shared.isAuthenticated,
              let userId = AuthService.shared.currentUser?.id.uuidString else {
            AppLogger.info("PlanService: refresh skipped (auth not ready), keeping cached plan=\(currentPlan.rawValue)", category: .general)
            return
        }

        struct OrgMemberRow: Decodable {
            let status: String?
            let organizations: OrgPlan?
            struct OrgPlan: Decodable { let plan: String? }
        }
        struct SubscriptionRow: Decodable {
            let status: String?
            let provider: String?
        }
        struct FeatureFlagRow: Decodable {
            let name: String
            let enabled: Bool
        }
        do {
            async let orgRowsTask: [OrgMemberRow] = LecsyAPIClient.shared.restGET(
                "/organization_members",
                query: [
                    "select": "status,organizations!inner(plan)",
                    "user_id": "eq.\(userId)",
                    "status": "eq.active",
                    "limit": "1",
                ]
            )
            async let subRowsTask: [SubscriptionRow] = LecsyAPIClient.shared.restGET(
                "/subscriptions",
                query: [
                    "select": "status,provider",
                    "user_id": "eq.\(userId)",
                    "status": "eq.active",
                    "limit": "1",
                ]
            )
            async let flagRowsTask: [FeatureFlagRow] = LecsyAPIClient.shared.restGET(
                "/feature_flags",
                query: [
                    "select": "name,enabled",
                    "name": "eq.b2c_stripe_checkout",
                    "limit": "1",
                ]
            )
            let orgRows = try await orgRowsTask
            let subRows = try await subRowsTask
            let flagRows = (try? await flagRowsTask) ?? []

            // レスポンス後に Task がキャンセルされていたら書き戻さない（stale 応答対策）
            if Task.isCancelled {
                AppLogger.info("PlanService: refresh result dropped (cancelled)", category: .general)
                return
            }
            // userId が refresh 開始時点と現在で同じか確認（ユーザー切替レース対策）
            guard AuthService.shared.currentUser?.id.uuidString == userId else {
                AppLogger.info("PlanService: refresh result dropped (user switched)", category: .general)
                return
            }

            let orgPro = orgRows.first?.organizations?.plan == "pro"
            let stripePro = subRows.first?.status == "active" &&
                            subRows.first?.provider == "stripe"

            if orgPro {
                setPlan(.pro, source: .organization)
                AppLogger.info("PlanService: Pro via org membership", category: .general)
            } else if stripePro {
                setPlan(.pro, source: .stripe)
                AppLogger.info("PlanService: Pro via Stripe subscription", category: .general)
            } else {
                setPlan(.free, source: .none)
                AppLogger.info("PlanService: Free (no active pro source)", category: .general)
            }
            b2cCheckoutEnabled = flagRows.first?.enabled ?? false
            lastRefreshed = Date()

            // Pro が確認できたら Deepgram websocket を裏で暖機。
            // これをしないと: cold launch → 即 record タップのケースで iOS の
            // stale HTTP/3 socket 検出に 4-5 秒持っていかれて、最初の字幕までに
            // 9 秒待たされる（実ユーザー報告）。認証直後＝最もクリーンな接続
            // タイミングで一度張っておけば、ユーザーの record タップ時には
            // preparedSession があるので即 handoff。
            // TranscriptionCoordinator.prepare() は dedup / 30秒で再張り付け済。
            if currentPlan == .pro {
                Task { @MainActor in
                    await TranscriptionCoordinator.shared.prepare()
                }
            }
        } catch {
            AppLogger.warning("PlanService refresh failed (keeping cached plan=\(currentPlan.rawValue)): \(error.localizedDescription)", category: .general)
        }
    }

    func setForceLocal(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.forceLocalKey)
        objectWillChange.send()
    }

    // MARK: - Private

    private func setPlan(_ plan: Plan, source: ProSource) {
        currentPlan = plan
        proSource = source
        UserDefaults.standard.set(plan.rawValue, forKey: Self.cachedPlanKey)
        UserDefaults.standard.set(source.rawValue, forKey: Self.cachedSourceKey)
    }

    private func clearPlan() {
        refreshTask?.cancel()
        currentPlan = .free
        proSource = .none
        UserDefaults.standard.removeObject(forKey: Self.cachedPlanKey)
        UserDefaults.standard.removeObject(forKey: Self.cachedSourceKey)
    }
}
