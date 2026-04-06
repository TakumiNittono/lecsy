//
//  PostLoginCoordinator.swift
//  lecsy
//
//  Runs after a successful sign-in to:
//  1) call activate_pending_memberships() so the user joins any orgs
//     that previously added them by email
//  2) refresh the local membership list
//  3) trigger a "joined organization" toast
//

import Foundation

@MainActor
final class PostLoginCoordinator {
    static let shared = PostLoginCoordinator()

    /// Call this immediately after Supabase sign-in completes.
    /// - Parameters:
    ///   - userId: authenticated user UUID
    ///   - email: authenticated user email (lowercased)
    ///   - accessToken: Supabase JWT
    func handleSignIn(userId: String, email: String, accessToken: String) async {
        SupabaseClient.shared.userId = userId
        SupabaseClient.shared.userEmail = email.lowercased()
        SupabaseClient.shared.accessToken = accessToken

        do {
            let activated = try await OrganizationAPI.shared.activatePendingMemberships()
            if !activated.isEmpty {
                // Refresh memberships in OrganizationService
                await refreshMemberships()
                // Show joined toast for the first activated org
                if let first = activated.first {
                    await showJoinedToast(orgId: first.org_id)
                }
            } else {
                await refreshMemberships()
            }
        } catch {
            #if DEBUG
            print("[PostLoginCoordinator] activate failed: \(error)")
            #endif
        }
    }

    /// Call on sign-out to clear cached state.
    func handleSignOut() {
        SupabaseClient.shared.userId = nil
        SupabaseClient.shared.userEmail = nil
        SupabaseClient.shared.accessToken = nil
    }

    private func refreshMemberships() async {
        do {
            let rows = try await OrganizationAPI.shared.listMyOrganizations()
            // Bridge to OrganizationService: take the first active org as current
            if let first = rows.first, let org = first.organizations {
                let mapped = Organization(
                    id: UUID(uuidString: org.id) ?? UUID(),
                    name: org.name,
                    slug: org.slug,
                    type: .languageSchool,
                    plan: OrganizationPlan(rawValue: org.plan ?? "starter") ?? .starter,
                    maxSeats: org.max_seats ?? 50
                )
                let role = OrganizationRole(rawValue: first.role) ?? .student
                OrganizationService.shared.joinOrganization(mapped, as: role)
            }
        } catch {
            #if DEBUG
            print("[PostLoginCoordinator] refresh memberships failed: \(error)")
            #endif
        }
    }

    private func showJoinedToast(orgId: String) async {
        // OrganizationService publishes the toast state already.
        // The bridge above triggers joinOrganization which sets it.
    }
}
