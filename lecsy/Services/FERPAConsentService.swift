//
//  FERPAConsentService.swift
//  lecsy
//
//  B2B minimum-data collection: record each student's FERPA-aligned consent
//  timestamp on their organization_members row so IEP/ESL directors can
//  produce evidence that students acknowledged Lecsy's data handling before
//  recording. See supabase/migrations/20260418000000_ferpa_consent.sql for
//  the schema and the "members_self_consent" RLS policy that lets users
//  stamp their own row.
//
//  Local cache: we store the consent instant in UserDefaults keyed by orgId
//  so the consent sheet only surfaces once per (device, org). The server is
//  the source of truth; the cache is a fast-path that avoids a REST call
//  every time the user opens Record.
//

import Foundation
import Combine

@MainActor
final class FERPAConsentService: ObservableObject {
    static let shared = FERPAConsentService()

    /// Published so SwiftUI can bind a ".sheet(isPresented:)" modal to it.
    @Published var shouldPromptConsent: Bool = false
    /// The org id the current prompt relates to. nil when no prompt pending.
    @Published var pendingPromptOrgId: String?

    private let api = LecsyAPIClient.shared

    private init() {}

    private func cacheKey(orgId: String) -> String {
        "lecsy.ferpaConsent.\(orgId)"
    }

    /// Returns true if this device already knows the user consented for
    /// `orgId`. Fast synchronous check — no network.
    func hasConsentedLocally(orgId: String) -> Bool {
        UserDefaults.standard.object(forKey: cacheKey(orgId: orgId)) != nil
    }

    /// Call this after sign-in once we know the user has an active org
    /// membership. If the server has no consent timestamp, flip
    /// `shouldPromptConsent` so the RecordView can present the sheet.
    func refreshConsentStatus(orgId: String) async {
        #if DEBUG
        // 開発ビルドでは同意シートを強制的に抑制。TestFlight / Release には効かない。
        // 本番 B2B フローは `#else` のサーバ参照ロジックで従来通り動く。
        shouldPromptConsent = false
        pendingPromptOrgId = nil
        return
        #else
        // Fast path: local cache says we already consented.
        if hasConsentedLocally(orgId: orgId) {
            shouldPromptConsent = false
            return
        }

        // Ask the server. RLS already restricts this to the caller's own row.
        struct Row: Decodable { let ferpa_consented_at: String? }
        do {
            let rows: [Row] = try await api.restGET(
                "/organization_members",
                query: [
                    "select": "ferpa_consented_at",
                    "org_id": "eq.\(orgId)",
                    "user_id": "eq.\(api.userId ?? "")",
                    "limit": "1"
                ]
            )
            if let consentedAt = rows.first?.ferpa_consented_at, !consentedAt.isEmpty {
                UserDefaults.standard.set(consentedAt, forKey: cacheKey(orgId: orgId))
                shouldPromptConsent = false
            } else {
                pendingPromptOrgId = orgId
                shouldPromptConsent = true
            }
        } catch {
            // Non-fatal: if we can't reach the server, don't block recording.
            // The next sign-in / app launch will retry.
            AppLogger.warning("FERPA consent status fetch failed: \(error)", category: .general)
        }
        #endif
    }

    /// Dismiss the consent sheet for the current app session without writing
    /// the server-side timestamp. Used as the "Continue Offline" escape hatch
    /// when the consent PATCH keeps failing on flaky wifi — the next sign-in
    /// or app launch will re-evaluate via `refreshConsentStatus` so audit
    /// integrity is preserved.
    func dismissPromptForSession() {
        shouldPromptConsent = false
        pendingPromptOrgId = nil
    }

    /// Persist the user's consent to Supabase via a direct REST PATCH.
    /// Writes the local cache on success so subsequent launches skip the
    /// network round-trip.
    func recordConsent(orgId: String) async -> Bool {
        guard let userId = api.userId else { return false }
        guard let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !supabaseURL.isEmpty else { return false }
        guard let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty else { return false }

        let consentedAt = ISO8601DateFormatter().string(from: Date())

        guard var comps = URLComponents(
            string: "\(supabaseURL)/rest/v1/organization_members"
        ) else { return false }
        comps.queryItems = [
            URLQueryItem(name: "org_id", value: "eq.\(orgId)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
        ]
        guard let url = comps.url else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = api.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        struct Body: Encodable { let ferpa_consented_at: String }
        do {
            req.httpBody = try JSONEncoder().encode(Body(ferpa_consented_at: consentedAt))
            let (_, resp) = try await sendWithStaleSocketRetry(req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                AppLogger.warning("FERPA consent PATCH non-2xx response", category: .general)
                return false
            }
            UserDefaults.standard.set(consentedAt, forKey: cacheKey(orgId: orgId))
            shouldPromptConsent = false
            pendingPromptOrgId = nil
            return true
        } catch {
            AppLogger.warning("FERPA consent PATCH failed: \(error)", category: .general)
            return false
        }
    }

    /// VPN / QUIC / iOS 由来の一時エラー (-1005 / -1009 / -1001 / -1006) で最大2回
    /// リトライ。SupabaseClient.send の方針と揃える。
    private func sendWithStaleSocketRetry(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: req)
        } catch let first as URLError where Self.isTransient(first) {
            AppLogger.warning(
                "URLSession \(first.code.rawValue) on FERPA PATCH — retrying (1/2)",
                category: .general
            )
            do {
                return try await URLSession.shared.data(for: req)
            } catch let second as URLError where Self.isTransient(second) {
                AppLogger.warning(
                    "URLSession \(second.code.rawValue) on FERPA PATCH — retrying (2/2)",
                    category: .general
                )
                return try await URLSession.shared.data(for: req)
            }
        }
    }

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .networkConnectionLost, .notConnectedToInternet, .timedOut, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
