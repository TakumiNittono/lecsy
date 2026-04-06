//
//  OrganizationService.swift
//  lecsy
//
//  B2B組織機能: メンバーシップ確認、用語集取得、クロス要約取得
//  ローカルキャッシュでオフライン閲覧対応
//

import Foundation
import Combine
import os.log

@MainActor
class OrganizationService: ObservableObject {
    static let shared = OrganizationService()

    // MARK: - Published State

    /// ユーザーの組織メンバーシップ（nil = 未所属 or 未確認）
    @Published var membership: OrgMembership?
    /// メンバーシップ確認済みフラグ
    @Published var isChecked: Bool = false
    /// 読み込み中
    @Published var isLoading: Bool = false

    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let config = SupabaseConfig.shared

    // MARK: - Cache

    private let glossaryCacheKey = "lecsy.orgGlossaryCache"
    private let crossSummaryCacheKey = "lecsy.orgCrossSummaryCache"
    private let membershipCacheKey = "lecsy.orgMembershipCache"

    /// 組織メンバーかどうか
    var isMember: Bool { membership != nil }

    /// 現在の組織
    var organization: Organization? { membership?.organization }

    /// 現在のロール
    var role: OrgRole? { membership?.role }

    private init() {
        // キャッシュからメンバーシップを復元
        restoreMembershipFromCache()
    }

    // MARK: - Membership Check

    /// ユーザーの組織メンバーシップを確認（ログイン後に呼ぶ）
    func checkMembership() async {
        guard authService.isAuthenticated else {
            membership = nil
            isChecked = true
            return
        }

        isLoading = true
        defer { isLoading = false; isChecked = true }

        do {
            guard let accessToken = await authService.accessToken else {
                AppLogger.warning("OrganizationService: No access token", category: .auth)
                return
            }

            // まず pending メンバーシップを自動アクティベーション
            await activatePendingMemberships()

            // Supabase REST APIで organization_members を取得
            // select=org_id,user_id,role,status,organizations(id,name,slug,type,plan,max_seats)
            let url = config.supabaseURL
                .appendingPathComponent("rest/v1/organization_members")

            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                AppLogger.warning("OrganizationService: Failed to create URL components", category: .auth)
                return
            }
            components.queryItems = [
                URLQueryItem(name: "select", value: "org_id,user_id,role,status,organizations(id,name,slug,type,plan,max_seats)"),
                URLQueryItem(name: "user_id", value: "eq.\(authService.currentUser?.id.uuidString ?? "")"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "limit", value: "1"),
            ]

            guard let requestURL = components.url else {
                AppLogger.warning("OrganizationService: Failed to create request URL", category: .auth)
                return
            }

            var request = URLRequest(url: requestURL)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                AppLogger.warning("OrganizationService: Membership check failed", category: .auth)
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let memberships = try decoder.decode([OrgMembership].self, from: data)

            if let first = memberships.first {
                membership = first
                cacheMembership(first)
                AppLogger.info("OrganizationService: Member of \(first.organization.name) as \(first.role.rawValue)", category: .auth)
            } else {
                membership = nil
                clearMembershipCache()
                AppLogger.debug("OrganizationService: Not a member of any organization", category: .auth)
            }
        } catch {
            AppLogger.error("OrganizationService: Membership check error - \(error.localizedDescription)", category: .auth)
            // キャッシュがあればそのまま使う
        }
    }

    /// メンバーシップをクリア（ログアウト時）
    func clearMembership() {
        membership = nil
        isChecked = false
        clearMembershipCache()
        clearGlossaryCache()
        clearCrossSummaryCache()
    }

    // MARK: - Auto Activation

    /// pending メンバーシップを自動アクティベーション（ログイン時）
    /// メールが一致する pending レコードに user_id を紐付けて active にする
    private func activatePendingMemberships() async {
        guard let accessToken = await authService.accessToken else { return }
        guard let email = authService.currentUser?.email,
              let userId = authService.currentUser?.id.uuidString else { return }

        // RPC呼び出しで pending → active に更新
        let url = config.supabaseURL.appendingPathComponent("rest/v1/rpc/activate_pending_memberships")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body: [String: String] = [
            "p_user_id": userId,
            "p_email": email.lowercased(),
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                AppLogger.debug("OrganizationService: Checked pending memberships", category: .auth)
            }
        } catch {
            AppLogger.debug("OrganizationService: Activate pending failed - \(error.localizedDescription)", category: .auth)
        }
    }

    // MARK: - Glossary

    /// 組織の用語集を取得
    func fetchGlossary(language: String? = nil, search: String? = nil) async -> [GlossaryTerm] {
        guard let mem = membership else { return loadGlossaryFromCache() }

        do {
            guard let accessToken = await authService.accessToken else { return loadGlossaryFromCache() }

            let url = config.supabaseURL.appendingPathComponent("rest/v1/org_glossaries")

            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return loadGlossaryFromCache()
            }
            var queryItems = [
                URLQueryItem(name: "select", value: "id,org_id,term,definition,language,category,source_transcript_id,created_at"),
                URLQueryItem(name: "org_id", value: "eq.\(mem.orgId.uuidString)"),
                URLQueryItem(name: "order", value: "term.asc"),
                URLQueryItem(name: "limit", value: "200"),
            ]

            if let lang = language, !lang.isEmpty {
                queryItems.append(URLQueryItem(name: "language", value: "eq.\(lang)"))
            }
            if let q = search, !q.isEmpty {
                queryItems.append(URLQueryItem(name: "term", value: "ilike.*\(q)*"))
            }

            components.queryItems = queryItems

            guard let requestURL = components.url else {
                return loadGlossaryFromCache()
            }

            var request = URLRequest(url: requestURL)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return loadGlossaryFromCache()
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let terms = try decoder.decode([GlossaryTerm].self, from: data)

            // キャッシュに保存
            cacheGlossary(terms)
            return terms
        } catch {
            AppLogger.error("OrganizationService: Glossary fetch error - \(error.localizedDescription)", category: .sync)
            return loadGlossaryFromCache()
        }
    }

    // MARK: - Cross Summary

    /// クロス要約を取得（Edge Function経由 — Bearer token認証）
    func fetchCrossSummary(transcriptId: UUID, targetLanguage: String) async throws -> CrossSummaryResult {
        guard membership != nil else {
            throw OrgError.notMember
        }

        // セッションリフレッシュ
        _ = await authService.refreshSession()

        guard let accessToken = await authService.accessToken else {
            throw OrgError.notAuthenticated
        }

        // Edge Functionを直接呼ぶ（SyncServiceと同じパターン）
        let functionURL = config.supabaseURL.appendingPathComponent("functions/v1/org-ai-assist")

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "mode": "cross_summary",
            "transcript_id": transcriptId.uuidString,
            "target_language": targetLanguage,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrgError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw OrgError.dailyLimitReached
            }
            if httpResponse.statusCode == 403 {
                throw OrgError.notMember
            }
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let message = errorData["error"] {
                throw OrgError.serverError(message)
            }
            throw OrgError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(CrossSummaryResult.self, from: data)

        // キャッシュに保存
        cacheCrossSummary(transcriptId: transcriptId, targetLanguage: targetLanguage, result: result)

        return result
    }

    /// キャッシュからクロス要約を取得
    func getCachedCrossSummary(transcriptId: UUID, targetLanguage: String) -> CrossSummaryResult? {
        let cached = loadCrossSummariesFromCache()
        return cached.first(where: {
            $0.transcriptId == transcriptId && $0.targetLanguage == targetLanguage
        })?.result
    }

    // MARK: - Cache: Membership

    private func cacheMembership(_ membership: OrgMembership) {
        do {
            let data = try JSONEncoder().encode(membership)
            UserDefaults.standard.set(data, forKey: membershipCacheKey)
        } catch {
            AppLogger.debug("OrganizationService: Failed to cache membership", category: .storage)
        }
    }

    private func restoreMembershipFromCache() {
        guard let data = UserDefaults.standard.data(forKey: membershipCacheKey) else { return }
        do {
            membership = try JSONDecoder().decode(OrgMembership.self, from: data)
        } catch {
            AppLogger.debug("OrganizationService: Failed to restore membership cache", category: .storage)
        }
    }

    private func clearMembershipCache() {
        UserDefaults.standard.removeObject(forKey: membershipCacheKey)
    }

    // MARK: - Cache: Glossary

    private var glossaryCacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("org_glossary_cache.json")
    }

    private func cacheGlossary(_ terms: [GlossaryTerm]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(terms)
            try data.write(to: glossaryCacheURL, options: .atomic)
        } catch {
            AppLogger.debug("OrganizationService: Failed to cache glossary", category: .storage)
        }
    }

    private func loadGlossaryFromCache() -> [GlossaryTerm] {
        guard let data = try? Data(contentsOf: glossaryCacheURL) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([GlossaryTerm].self, from: data)
        } catch {
            return []
        }
    }

    private func clearGlossaryCache() {
        try? FileManager.default.removeItem(at: glossaryCacheURL)
    }

    // MARK: - Cache: Cross Summary

    private var crossSummaryCacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("org_cross_summary_cache.json")
    }

    private func cacheCrossSummary(transcriptId: UUID, targetLanguage: String, result: CrossSummaryResult) {
        var cached = loadCrossSummariesFromCache()
        // 同じキーがあれば上書き
        cached.removeAll { $0.transcriptId == transcriptId && $0.targetLanguage == targetLanguage }
        cached.append(CachedCrossSummary(
            transcriptId: transcriptId,
            targetLanguage: targetLanguage,
            result: result,
            cachedAt: Date()
        ))
        // 最新50件に絞る
        if cached.count > 50 {
            cached = Array(cached.suffix(50))
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cached)
            try data.write(to: crossSummaryCacheURL, options: .atomic)
        } catch {
            AppLogger.debug("OrganizationService: Failed to cache cross summary", category: .storage)
        }
    }

    private func loadCrossSummariesFromCache() -> [CachedCrossSummary] {
        guard let data = try? Data(contentsOf: crossSummaryCacheURL) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([CachedCrossSummary].self, from: data)
        } catch {
            return []
        }
    }

    private func clearCrossSummaryCache() {
        try? FileManager.default.removeItem(at: crossSummaryCacheURL)
    }
}

// MARK: - Errors

enum OrgError: LocalizedError {
    case notMember
    case notAuthenticated
    case networkError
    case dailyLimitReached
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notMember:
            return "Organization membership required"
        case .notAuthenticated:
            return "Please sign in to use this feature"
        case .networkError:
            return "Network error. Please check your connection."
        case .dailyLimitReached:
            return "Daily AI limit reached for your organization. Try again tomorrow."
        case .serverError(let message):
            return message
        }
    }
}
