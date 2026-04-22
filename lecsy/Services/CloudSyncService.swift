//
//  CloudSyncService.swift
//  lecsy
//
//  Auto-uploads completed transcript text (NOT audio) to Supabase so:
//   1) B2B school admins can see student activity in /org/[slug]
//   2) Users don't lose their notes when their iPhone breaks
//
//  Strategic context: see doc/STRATEGIC_REVIEW_2026Q2.md.
//  Key invariants — do not break without re-reading the strategy doc:
//   - Audio (.m4a) is NEVER uploaded. Only the transcript text + metadata.
//     This is what differentiates us from Otter (currently in a class-action
//     lawsuit for storing/training on raw audio).
//   - Upload is fire-and-forget. Failure must NEVER block the local lecture
//     save flow — local-first remains the source of truth on device.
//   - Upload is gated by `lecsyCloudSyncEnabled` (default OFF — opt-in for
//     App Store privacy compliance). Users enable per-device from PrivacySettingsView.
//   - Anonymous users (skipped sign-in) are silently skipped.
//

import Foundation
import Combine

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    /// True while a backfill pass is running. UI binds to this for spinners.
    @Published var isBackfilling: Bool = false
    /// Result of the most recent backfill: "uploaded / total". nil if never run.
    @Published var lastBackfillSummary: String?

    /// UserDefaults key for the per-device cloud sync toggle.
    /// Default OFF (opt-in for App Store privacy compliance). Users enable from PrivacySettingsView.
    static let cloudSyncEnabledKey = "lecsy.cloudSyncEnabled"

    private let api = LecsyAPIClient.shared

    private init() {}

    /// Whether the user has cloud sync enabled on this device.
    var isEnabled: Bool {
        // Default false (opt-in). User must explicitly enable in Privacy settings.
        if UserDefaults.standard.object(forKey: Self.cloudSyncEnabledKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: Self.cloudSyncEnabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.cloudSyncEnabledKey)
    }

    /// ユーザーが Settings でまだ touch していない場合のみ cloudSync を ON にする。
    /// B2B org メンバー確定時に呼ぶことで、Recent Activity / 管理画面に録音が自動で
    /// 流れる状態を作る。既にユーザーが明示的に OFF を選んでいる場合は上書きしない。
    func enableForOrgMemberIfUnset() {
        guard UserDefaults.standard.object(forKey: Self.cloudSyncEnabledKey) == nil else { return }
        UserDefaults.standard.set(true, forKey: Self.cloudSyncEnabledKey)
        AppLogger.info("CloudSync auto-enabled (org member, opt-in default)", category: .recording)
    }

    /// Upload a completed transcript to Supabase.
    /// Fire-and-forget. Returns the remote transcript id on success, nil on
    /// any failure (auth missing, sync disabled, network error, etc.).
    @discardableResult
    func uploadTranscriptIfEnabled(
        clientId: UUID? = nil,
        title: String,
        content: String,
        createdAt: Date,
        durationSeconds: Double?,
        language: String?
    ) async -> String? {
        // Gate 1: user opted out on this device
        guard isEnabled else {
            AppLogger.debug("Cloud sync disabled, skipping upload", category: .recording)
            return nil
        }
        // Gate 2: must be signed in (anonymous skip)
        guard AuthService.shared.currentUser != nil else {
            AppLogger.debug("No signed-in user, skipping cloud sync", category: .recording)
            return nil
        }
        // Gate 3: must have non-empty content
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Resolve org context (nil for B2C users, populated for org members)
        let orgContext = OrganizationContext.shared.saveContext()
        // Warn if user is an org member but context is nil — likely a PostLoginCoordinator issue
        if orgContext == nil && AuthService.shared.isOrgMember {
            AppLogger.warning(
                "Cloud sync: user is org member but OrganizationContext is nil — recording will save as private",
                category: .recording
            )
        }

        struct SavePayload: Encodable {
            let title: String
            let content: String
            let created_at: String
            let duration: Double?
            let language: String?
            let client_id: String?
            let organization_id: String?
            let visibility: String?
            // class_id は 2026-04-07 b2b_simplify で DB 側の列を drop 済。Edge Function も
            // もう参照しない。payload から削除して死データ送出をやめる。
        }

        struct SaveResp: Decodable {
            let id: String
            let created_at: String?
        }

        let payload = SavePayload(
            title: title,
            content: content,
            created_at: ISO8601DateFormatter().string(from: createdAt),
            duration: durationSeconds,
            language: language,
            client_id: clientId?.uuidString,
            organization_id: orgContext?.orgId,
            visibility: orgContext?.visibility
        )

        do {
            let resp: SaveResp = try await api.invokeFunction(
                "save-transcript",
                body: payload,
                timeout: 60
            )
            AppLogger.info(
                "Cloud-synced transcript: id=\(resp.id) org=\(orgContext?.orgId ?? "none")",
                category: .recording
            )
            return resp.id
        } catch {
            // Fire-and-forget: log only, never bubble up.
            // SupabaseError.server は errorDescription にレスポンス body を含むので、
            // 「HTTP 500」ではなく「Server error 500: {code=23505, details=...}」が
            // Sentry に残る。Sentry SDK の auto HTTPClientError は body を持たないので、
            // こちらを結合診断用の主シグナルにする。
            let detail: String
            if case let SupabaseError.server(body, code) = error {
                detail = "HTTP \(code) from save-transcript: \(body.prefix(600))"
            } else {
                detail = "save-transcript invoke failed: \(error)"
            }
            AppLogger.error(
                "Cloud sync upload failed (will retry on next save). \(detail)",
                category: .recording
            )
            // 型付き error を別チャンネルで capture。Sentry 上のスタック/ドメインが保持される。
            AppLogger.capture(error, category: .recording)
            return nil
        }
    }

    /// Per-device flag so we only auto-backfill once after the first sign-in.
    /// Resetting (e.g. for QA) clears `lecsy.cloudBackfillDone` from UserDefaults.
    private static let backfillDoneKey = "lecsy.cloudBackfillDone"

    /// Best-effort backfill of all locally-stored lectures with non-empty
    /// transcripts. Idempotent: save-transcript dedupes by (user_id, client_id).
    /// Runs sequentially to avoid hammering the Edge Function. Skips if
    /// already done on this device for this user.
    func backfillAllLocalLecturesIfNeeded(store: LectureStore) async {
        guard let user = AuthService.shared.currentUser else { return }
        let key = "\(Self.backfillDoneKey).\(user.id.uuidString)"
        if UserDefaults.standard.bool(forKey: key) { return }
        let allSucceeded = await runBackfill(store: store)
        // Only set the once-per-user flag when EVERY candidate uploaded
        // successfully. If a partial failure happens (network drop, etc.),
        // we want the next sign-in / app launch to retry the missing rows.
        if allSucceeded {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    /// Manual backfill triggered from Settings UI. Always runs.
    @discardableResult
    func backfillAllLocalLectures(store: LectureStore) async -> Bool {
        return await runBackfill(store: store)
    }

    /// Returns true if every candidate uploaded successfully.
    @discardableResult
    private func runBackfill(store: LectureStore) async -> Bool {
        guard isEnabled else { return false }
        guard AuthService.shared.currentUser != nil else { return false }
        guard !isBackfilling else { return false }

        isBackfilling = true
        let candidates = store.lectures.filter {
            !($0.transcriptText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        var uploaded = 0
        for lecture in candidates {
            let id = await uploadTranscriptIfEnabled(
                clientId: lecture.id,
                title: lecture.title,
                content: lecture.transcriptText ?? "",
                createdAt: lecture.createdAt,
                durationSeconds: lecture.duration,
                language: lecture.language.rawValue
            )
            if id != nil { uploaded += 1 }
        }
        lastBackfillSummary = "\(uploaded) / \(candidates.count) backed up"
        isBackfilling = false
        AppLogger.info("Cloud backfill: \(uploaded)/\(candidates.count)", category: .recording)
        return uploaded == candidates.count
    }
}
