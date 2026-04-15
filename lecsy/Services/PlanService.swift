//
//  PlanService.swift
//  lecsy
//
//  B2B 専用:
//    - Pro判定の唯一の根拠 = active な organization_members かつ org.plan='pro'
//    - B2C（org非所属）は常に Free、WhisperKit のみ
//    - Force local transcription ON → Pro でも WhisperKit を使う（QA用）
//
//  耐障害性:
//    - 一度 Pro と判定したプランを UserDefaults にキャッシュ、次回起動時に即復元
//    - refresh 中の一時的な失敗（JWT期限切れ、ネットワーク断、初期化レース）では Pro を降格しない
//    - 降格は「認証状態が完全に揃った上で、明示的に org.plan!='pro' が確認できた」時のみ
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

    static let forceLocalKey = "lecsy.forceLocalTranscription"
    private static let cachedPlanKey = "lecsy.cachedPlan"

    @Published private(set) var currentPlan: Plan = .free
    @Published private(set) var lastRefreshed: Date?

    private var cancellables: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.cachedPlanKey),
           let cached = Plan(rawValue: raw) {
            currentPlan = cached
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
        do {
            let rows: [OrgMemberRow] = try await LecsyAPIClient.shared.restGET(
                "/organization_members",
                query: [
                    "select": "status,organizations!inner(plan)",
                    "user_id": "eq.\(userId)",
                    "status": "eq.active",
                    "limit": "1",
                ]
            )
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
            if let m = rows.first, m.organizations?.plan == "pro" {
                setPlan(.pro)
                AppLogger.info("PlanService: Pro via org membership", category: .general)
            } else {
                setPlan(.free)
                AppLogger.info("PlanService: Free (no active pro org)", category: .general)
            }
            lastRefreshed = Date()
        } catch {
            AppLogger.warning("PlanService refresh failed (keeping cached plan=\(currentPlan.rawValue)): \(error.localizedDescription)", category: .general)
        }
    }

    func setForceLocal(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.forceLocalKey)
        objectWillChange.send()
    }

    // MARK: - Private

    private func setPlan(_ plan: Plan) {
        currentPlan = plan
        UserDefaults.standard.set(plan.rawValue, forKey: Self.cachedPlanKey)
    }

    private func clearPlan() {
        refreshTask?.cancel()
        currentPlan = .free
        UserDefaults.standard.removeObject(forKey: Self.cachedPlanKey)
    }
}
