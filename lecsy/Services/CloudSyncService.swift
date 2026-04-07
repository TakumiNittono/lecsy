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
//   - Upload is gated by `lecsyCloudSyncEnabled` (default ON). Users can
//     opt out per-device from PrivacySettingsView.
//   - Anonymous users (skipped sign-in) are silently skipped.
//

import Foundation

@MainActor
final class CloudSyncService {
    static let shared = CloudSyncService()

    /// UserDefaults key for the per-device cloud sync toggle.
    /// Default ON. Users can disable from PrivacySettingsView.
    static let cloudSyncEnabledKey = "lecsy.cloudSyncEnabled"

    private let api = LecsyAPIClient.shared

    private init() {}

    /// Whether the user has cloud sync enabled on this device.
    var isEnabled: Bool {
        // Default true (opt-out, not opt-in)
        if UserDefaults.standard.object(forKey: Self.cloudSyncEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: Self.cloudSyncEnabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.cloudSyncEnabledKey)
    }

    /// Upload a completed transcript to Supabase.
    /// Fire-and-forget. Returns the remote transcript id on success, nil on
    /// any failure (auth missing, sync disabled, network error, etc.).
    @discardableResult
    func uploadTranscriptIfEnabled(
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

        struct SavePayload: Encodable {
            let title: String
            let content: String
            let created_at: String
            let duration: Double?
            let language: String?
            let organization_id: String?
            let visibility: String?
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
            AppLogger.warning(
                "Cloud sync upload failed (will retry on next save): \(error)",
                category: .recording
            )
            return nil
        }
    }
}
