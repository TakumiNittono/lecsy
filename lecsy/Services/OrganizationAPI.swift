//
//  OrganizationAPI.swift
//  lecsy
//
//  Real Supabase calls for B2B v4 features. Used by OrganizationService
//  when not in demo mode.
//

import Foundation

@MainActor
final class OrganizationAPI {
    static let shared = OrganizationAPI()
    private let sb = LecsyAPIClient.shared

    // MARK: - Post-login activation

    /// Called after sign-in. Activates any pending memberships matching the user's email.
    /// Returns the rows that were activated (so we can show a toast).
    func activatePendingMemberships() async throws -> [ActivatedMembership] {
        guard let uid = sb.userId, let email = sb.userEmail else { return [] }
        return try await sb.rpc("activate_pending_memberships",
                                params: ["p_user_id": uid, "p_email": email.lowercased()])
    }

    // MARK: - Membership listing

    func listMyOrganizations() async throws -> [OrgMembershipRow] {
        try await sb.restGET(
            "/organization_members",
            query: [
                "select": "org_id,role,status,organizations(id,name,slug,plan,max_seats,locale)",
                "user_id": "eq.\(sb.userId ?? "")",
                "status": "eq.active"
            ]
        )
    }

    // MARK: - Members CRUD (admin+)

    func listMembers(orgId: String) async throws -> [MemberRow] {
        try await sb.restGET(
            "/organization_members",
            query: [
                "select": "id,user_id,email,role,status,joined_at",
                "org_id": "eq.\(orgId)",
                "order": "joined_at.desc",
                "limit": "500"
            ]
        )
    }

    func addMember(orgId: String, email: String, role: String) async throws {
        struct Body: Encodable { let org_id: String; let email: String; let role: String; let status = "pending" }
        let _: [MemberRow] = try await sb.restPOST(
            "/organization_members",
            body: Body(org_id: orgId, email: email.lowercased(), role: role)
        )

        // 招待メールを送る (Edge Function 経由 / best-effort)
        // 失敗しても pending 行はあるので Apple/Google サインインで自動ジョイン可能
        struct InviteBody: Encodable { let org_id: String; let email: String }
        struct InviteResp: Decodable { let ok: Bool? }
        do {
            let _: InviteResp = try await sb.invokeFunction(
                "send-org-invite",
                body: InviteBody(org_id: orgId, email: email.lowercased())
            )
        } catch {
            // 招待送信失敗はログのみ。メンバー追加自体は成功扱い。
            print("[OrganizationAPI] send-org-invite failed (non-fatal): \(error)")
        }
    }

    func removeMember(memberId: String) async throws {
        var req = URLRequest(url: URL(string: "\(Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "")/rest/v1/organization_members?id=eq.\(memberId)")!)
        req.httpMethod = "DELETE"
        if let token = sb.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue((Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String) ?? "", forHTTPHeaderField: "apikey")
        _ = try await URLSession.shared.data(for: req)
    }

    func updateMemberRole(memberId: String, newRole: String) async throws {
        struct Body: Encodable { let role: String }
        let url = URL(string: "\(Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "")/rest/v1/organization_members?id=eq.\(memberId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = sb.accessToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue((Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String) ?? "", forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(Body(role: newRole))
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Super admin (Edge Functions)

    struct CreateOrgPayload: Encodable {
        let name: String
        let slug: String
        let type: String
        let plan: String
        let max_seats: Int
        let owner_email: String?
    }
    struct CreateOrgResponse: Decodable { let organization: OrgRow }

    func createOrganization(_ payload: CreateOrgPayload) async throws -> OrgRow {
        let r: CreateOrgResponse = try await sb.invokeFunction("org-create", body: payload)
        return r.organization
    }

    struct GrantOwnershipPayload: Encodable { let org_id: String; let email: String }
    struct GrantOwnershipResponse: Decodable { let ok: Bool; let action: String; let member_id: String }

    func grantOwnership(orgId: String, email: String) async throws -> GrantOwnershipResponse {
        try await sb.invokeFunction("org-grant-ownership",
                                    body: GrantOwnershipPayload(org_id: orgId, email: email.lowercased()))
    }

    func listAllOrganizations() async throws -> [OrgRow] {
        try await sb.restGET(
            "/organizations",
            query: ["select": "*", "order": "created_at.desc", "limit": "500"]
        )
    }

    // MARK: - CSV import (admin+)

    struct CsvImportRow: Codable { let email: String; let role: String }
    struct CsvImportPayload: Encodable { let org_id: String; let rows: [CsvImportRow] }
    struct CsvImportResponse: Decodable {
        struct Success: Decodable { let email: String; let status: String }
        struct Failure: Decodable { let row: Int; let email: String; let reason: String }
        struct Summary: Decodable { let total: Int; let ok: Int; let ng: Int }
        let successes: [Success]?
        let failures: [Failure]
        let summary: Summary
    }

    func csvImport(orgId: String, rows: [CsvImportRow]) async throws -> CsvImportResponse {
        try await sb.invokeFunction("org-csv-import",
                                    body: CsvImportPayload(org_id: orgId, rows: rows))
    }
}

// MARK: - DTOs

struct ActivatedMembership: Decodable {
    let id: String
    let org_id: String
    let role: String
    let status: String
}

struct OrgRow: Decodable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let plan: String?
    let max_seats: Int?
    let locale: String?
    let created_at: String?
}

struct OrgMembershipRow: Decodable {
    let org_id: String
    let role: String
    let status: String
    let organizations: OrgRow?
}

struct MemberRow: Decodable, Identifiable {
    let id: String
    let user_id: String?
    let email: String?
    let role: String
    let status: String
    let joined_at: String?
}
