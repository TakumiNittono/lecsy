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

/// Notification posted by any auth/sign-in flow once a Supabase session is
/// available. Object payload must be a `[String: String]` with keys
/// `userId`, `email`, `accessToken`. PostLoginCoordinator listens for this
/// and runs `handleSignIn` automatically — so future Supabase / OAuth
/// integration only has to `post(name: .lecsyDidSignIn, ...)`.
extension Notification.Name {
    static let lecsyDidSignIn  = Notification.Name("lecsy.didSignIn")
    static let lecsyDidSignOut = Notification.Name("lecsy.didSignOut")
}

@MainActor
final class PostLoginCoordinator {
    static let shared = PostLoginCoordinator()

    private init() {
        // Observe sign-in / sign-out notifications so auth code can stay decoupled.
        NotificationCenter.default.addObserver(
            forName: .lecsyDidSignIn, object: nil, queue: .main
        ) { note in
            guard let info = note.userInfo as? [String: String],
                  let uid = info["userId"],
                  let email = info["email"],
                  let token = info["accessToken"] else { return }
            Task { @MainActor in
                await PostLoginCoordinator.shared.handleSignIn(
                    userId: uid, email: email, accessToken: token
                )
            }
        }
        NotificationCenter.default.addObserver(
            forName: .lecsyDidSignOut, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in PostLoginCoordinator.shared.handleSignOut() }
        }
    }

    /// Call this immediately after Supabase sign-in completes.
    /// - Parameters:
    ///   - userId: authenticated user UUID
    ///   - email: authenticated user email (lowercased)
    ///   - accessToken: Supabase JWT
    func handleSignIn(userId: String, email: String, accessToken: String) async {
        // No need to push tokens into LecsyAPIClient — it now reads them
        // directly from AuthService.shared (single source of truth).

        // Guard: token must be present before making API calls.
        guard AuthService.shared.cachedAccessToken != nil else {
            AppLogger.error("handleSignIn called but cachedAccessToken is nil — skipping org activation", category: .auth)
            return
        }

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
            AppLogger.warning("activate pending memberships failed: \(error)", category: .auth)
            // Still try to refresh memberships — user may already be active
            await refreshMemberships()
        }
    }

    /// Call on sign-out to clear cached state.
    /// LecsyAPIClient automatically reflects sign-out via AuthService.
    func handleSignOut() {
        OrganizationContext.shared.clear()
    }

    /// Maximum retry attempts for membership refresh (network can be flaky).
    private static let maxRetries = 3

    private func refreshMemberships() async {
        for attempt in 1...Self.maxRetries {
            do {
                let rows = try await OrganizationAPI.shared.listMyOrganizations()
                // Bridge to OrganizationService: take the first active org as current
                if let first = rows.first, let org = first.organizations {
                    let mapped = Organization(
                        id: UUID(uuidString: org.id) ?? UUID(),
                        name: org.name,
                        slug: org.slug,
                        type: .languageSchool,
                        plan: OrganizationPlan(rawValue: org.plan ?? "free") ?? .free,
                        maxSeats: org.max_seats ?? 50
                    )
                    let role = OrganizationRole(rawValue: first.role) ?? .student
                    OrganizationService.shared.joinOrganization(mapped, as: role)
                    // Adopt org context for new recordings (Phase 1.5 #4).
                    OrganizationContext.shared.adoptDefaultContext(orgId: org.id)
                    AppLogger.info("Org context adopted: \(org.id) (\(org.name))", category: .auth)
                } else {
                    AppLogger.debug("No active org memberships found", category: .auth)
                }
                return // success — exit retry loop
            } catch {
                AppLogger.warning("refreshMemberships attempt \(attempt)/\(Self.maxRetries) failed: \(error)", category: .auth)
                if attempt < Self.maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000) // 1s, 2s backoff
                }
            }
        }
        AppLogger.error("refreshMemberships exhausted all retries — org context will be nil", category: .auth)
    }

    private func showJoinedToast(orgId: String) async {
        // OrganizationService publishes the toast state already.
        // The bridge above triggers joinOrganization which sets it.
    }
}
