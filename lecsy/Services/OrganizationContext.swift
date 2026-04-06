//
//  OrganizationContext.swift
//  lecsy
//
//  Lightweight singleton that holds the *active* organization context
//  used when saving a recording / transcript. Set after sign-in by
//  PostLoginCoordinator (if the user has an active membership) or
//  toggled by the user from the recording sheet.
//
//  Kept deliberately tiny — see Phase 1.5 #4 in CURRENT_STATUS.md.
//

import Foundation
import Combine

@MainActor
final class OrganizationContext: ObservableObject {
    static let shared = OrganizationContext()

    /// The org id (UUID string) the next saved recording should be attached to.
    /// nil means "B2C / private", i.e. no organization context.
    @Published var activeOrgId: String?

    /// Visibility level for newly saved recordings inside the active org.
    /// Ignored when `activeOrgId` is nil.
    @Published var visibility: Visibility = .private_

    /// Optional class id (for visibility == .class).
    @Published var classId: String?

    /// User-facing toggle: should new recordings inherit the active org context?
    /// When false, recordings are saved as private B2C even if the user is in an org.
    @Published var attachToOrganization: Bool = true

    enum Visibility: String {
        case private_ = "private"
        case `class`  = "class"
        case orgWide  = "org_wide"
    }

    private init() {}

    /// Returns the (org_id, visibility, class_id) tuple to attach to a save call,
    /// or nil if no org context should be applied.
    func saveContext() -> (orgId: String, visibility: String, classId: String?)? {
        guard attachToOrganization, let orgId = activeOrgId else { return nil }
        return (orgId, visibility.rawValue, classId)
    }

    /// Called by PostLoginCoordinator after the user's first active membership
    /// is fetched. Sets a sensible default (org-attached, private visibility).
    func adoptDefaultContext(orgId: String) {
        self.activeOrgId = orgId
        self.visibility = .private_
        self.classId = nil
        self.attachToOrganization = true
    }

    func clear() {
        self.activeOrgId = nil
        self.classId = nil
        self.visibility = .private_
    }
}
