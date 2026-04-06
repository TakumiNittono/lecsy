//
//  OrganizationService.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import Foundation
import Combine

/// Manages organization state for B2B features.
/// Uses mock data for simulator testing; will connect to Supabase in production.
@MainActor
class OrganizationService: ObservableObject {
    static let shared = OrganizationService()

    // MARK: - Published State

    @Published var currentOrganization: Organization?
    @Published var currentMembership: OrganizationMember?
    @Published var members: [OrganizationMember] = []
    @Published var classes: [OrganizationClass] = []
    @Published var glossaryEntries: [GlossaryEntry] = []
    @Published var organizations: [Organization] = []
    @Published var showJoinedToast = false
    @Published var joinedOrgName = ""

    /// Whether B2B demo mode is active
    @Published var isDemoMode: Bool {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: demoModeKey)
            if isDemoMode {
                loadDemoData()
            } else {
                clearOrgData()
            }
        }
    }

    private let demoModeKey = "lecsy.b2b.demoMode"

    // MARK: - Computed

    var isInOrganization: Bool { currentOrganization != nil }
    var currentRole: OrganizationRole? { currentMembership?.role }

    var activeMembers: [OrganizationMember] {
        members.filter { $0.status == .active }
    }

    var pendingMembers: [OrganizationMember] {
        members.filter { $0.status == .pending }
    }

    var teacherCount: Int {
        activeMembers.filter { $0.role == .teacher || $0.role == .admin || $0.role == .owner }.count
    }

    var studentCount: Int {
        activeMembers.filter { $0.role == .student }.count
    }

    // MARK: - Init

    private init() {
        isDemoMode = UserDefaults.standard.bool(forKey: demoModeKey)
        if isDemoMode {
            loadDemoData()
        }
    }

    // MARK: - Organization Actions

    func joinOrganization(_ org: Organization, as role: OrganizationRole) {
        currentOrganization = org
        currentMembership = OrganizationMember(
            organizationId: org.id,
            userId: UUID(),
            email: "demo@lecsy.app",
            displayName: "Demo User",
            role: role,
            status: .active
        )
        if !organizations.contains(where: { $0.id == org.id }) {
            organizations.append(org)
        }
        joinedOrgName = org.name
        showJoinedToast = true
    }

    func leaveOrganization() {
        currentOrganization = nil
        currentMembership = nil
        members = []
        classes = []
    }

    func switchOrganization(to org: Organization) {
        guard let membership = mockMembershipFor(org) else { return }
        currentOrganization = org
        currentMembership = membership
        loadMembersForCurrentOrg()
        loadClassesForCurrentOrg()
    }

    // MARK: - Member Management

    func addMember(email: String, displayName: String, role: OrganizationRole) {
        guard let org = currentOrganization else { return }
        let member = OrganizationMember(
            organizationId: org.id,
            email: email,
            displayName: displayName,
            role: role,
            status: .pending
        )
        members.append(member)
    }

    func removeMember(_ member: OrganizationMember) {
        members.removeAll { $0.id == member.id }
    }

    func updateMemberRole(_ member: OrganizationMember, to newRole: OrganizationRole) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].role = newRole
    }

    func activateMember(_ member: OrganizationMember) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].status = .active
        members[index].userId = UUID()
    }

    // MARK: - Class Management

    func addClass(name: String, language: TranscriptionLanguage, semester: String) {
        guard let org = currentOrganization else { return }
        let orgClass = OrganizationClass(
            organizationId: org.id,
            name: name,
            language: language,
            semester: semester
        )
        classes.append(orgClass)
    }

    func removeClass(_ orgClass: OrganizationClass) {
        classes.removeAll { $0.id == orgClass.id }
    }

    // MARK: - Glossary

    func addGlossaryEntry(_ entry: GlossaryEntry) {
        glossaryEntries.append(entry)
    }

    func removeGlossaryEntry(_ entry: GlossaryEntry) {
        glossaryEntries.removeAll { $0.id == entry.id }
    }

    // MARK: - Demo Data

    func loadDemoData() {
        let orgId = UUID()

        // Demo organization
        let demoOrg = Organization(
            id: orgId,
            name: "OHLA Orlando",
            slug: "ohla-orlando",
            type: .languageSchool,
            plan: .growth,
            maxSeats: 50,
            createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        )

        let demoOrg2 = Organization(
            id: UUID(),
            name: "Miami Dade College IEP",
            slug: "mdc-iep",
            type: .universityIEP,
            plan: .starter,
            maxSeats: 30,
            createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        )

        organizations = [demoOrg, demoOrg2]
        currentOrganization = demoOrg

        // Current user as admin
        let currentUserId = UUID()
        currentMembership = OrganizationMember(
            organizationId: orgId,
            userId: currentUserId,
            email: "takumi@lecsy.app",
            displayName: "Takumi (You)",
            role: .owner,
            status: .active,
            joinedAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        )

        // Demo members
        let teacherId1 = UUID()
        let teacherId2 = UUID()
        members = [
            currentMembership!,
            OrganizationMember(
                organizationId: orgId,
                userId: teacherId1,
                email: "sarah.j@ohla.edu",
                displayName: "Sarah Johnson",
                role: .teacher,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                userId: teacherId2,
                email: "mike.c@ohla.edu",
                displayName: "Michael Chen",
                role: .teacher,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                userId: UUID(),
                email: "maria.g@student.ohla.edu",
                displayName: "Maria Garcia",
                role: .student,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                userId: UUID(),
                email: "yuki.t@student.ohla.edu",
                displayName: "Yuki Tanaka",
                role: .student,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .day, value: -40, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                userId: UUID(),
                email: "ahmed.k@student.ohla.edu",
                displayName: "Ahmed Khan",
                role: .student,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .day, value: -38, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                userId: UUID(),
                email: "sofia.r@student.ohla.edu",
                displayName: "Sofia Rodriguez",
                role: .student,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                userId: UUID(),
                email: "wei.l@student.ohla.edu",
                displayName: "Wei Liu",
                role: .student,
                status: .active,
                joinedAt: Calendar.current.date(byAdding: .day, value: -25, to: Date()) ?? Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                email: "new.student@ohla.edu",
                displayName: "New Student",
                role: .student,
                status: .pending,
                joinedAt: Date()
            ),
            OrganizationMember(
                organizationId: orgId,
                email: "pending.teacher@ohla.edu",
                displayName: "Pending Teacher",
                role: .teacher,
                status: .pending,
                joinedAt: Date()
            ),
        ]

        // Demo classes
        classes = [
            OrganizationClass(
                organizationId: orgId,
                name: "Advanced English Listening",
                language: .english,
                semester: "Spring 2026",
                teacherId: teacherId1,
                studentIds: members.filter { $0.role == .student && $0.status == .active }.prefix(3).map { $0.id }
            ),
            OrganizationClass(
                organizationId: orgId,
                name: "Business English",
                language: .english,
                semester: "Spring 2026",
                teacherId: teacherId2,
                studentIds: members.filter { $0.role == .student && $0.status == .active }.suffix(2).map { $0.id }
            ),
            OrganizationClass(
                organizationId: orgId,
                name: "TOEFL Preparation",
                language: .english,
                semester: "Spring 2026",
                teacherId: teacherId1,
                studentIds: members.filter { $0.role == .student && $0.status == .active }.map { $0.id }
            ),
        ]

        // Demo glossary entries
        glossaryEntries = [
            GlossaryEntry(
                organizationId: orgId,
                term: "Collocation",
                definition: "A combination of words that frequently occur together",
                example: "\"Make a decision\" is a common collocation.",
                targetLanguage: .spanish,
                translation: "Colocacion",
                difficulty: .intermediate,
                createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
            ),
            GlossaryEntry(
                organizationId: orgId,
                term: "Inference",
                definition: "A conclusion reached on the basis of evidence and reasoning",
                example: "From the context, we can make an inference about the speaker's opinion.",
                targetLanguage: .japanese,
                translation: "推論",
                difficulty: .advanced,
                createdAt: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date()
            ),
            GlossaryEntry(
                organizationId: orgId,
                term: "Paraphrase",
                definition: "Express the meaning using different words",
                example: "Can you paraphrase what the lecturer said?",
                targetLanguage: .chinese,
                translation: "释义",
                difficulty: .intermediate,
                createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
            ),
            GlossaryEntry(
                organizationId: orgId,
                term: "Cognate",
                definition: "A word that has the same origin as a word in another language",
                example: "\"Family\" in English and \"familia\" in Spanish are cognates.",
                targetLanguage: .spanish,
                translation: "Cognado",
                difficulty: .beginner,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            ),
            GlossaryEntry(
                organizationId: orgId,
                term: "Morpheme",
                definition: "The smallest meaningful unit of a language",
                example: "The word 'unhappiness' contains three morphemes: un-, happy, -ness.",
                targetLanguage: .korean,
                translation: "형태소",
                difficulty: .advanced,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            ),
        ]
    }

    private func clearOrgData() {
        currentOrganization = nil
        currentMembership = nil
        members = []
        classes = []
        glossaryEntries = []
        organizations = []
    }

    private func mockMembershipFor(_ org: Organization) -> OrganizationMember? {
        return OrganizationMember(
            organizationId: org.id,
            userId: UUID(),
            email: "takumi@lecsy.app",
            displayName: "Takumi (You)",
            role: .owner,
            status: .active
        )
    }

    private func loadMembersForCurrentOrg() {
        // In production, fetch from Supabase
    }

    private func loadClassesForCurrentOrg() {
        // In production, fetch from Supabase
    }

    // MARK: - Usage Stats (Mock)

    struct UsageStats {
        let todayRecordings: Int
        let weekRecordings: Int
        let monthRecordings: Int
        let activeUsersToday: Int
        let aiUsageToday: Int
        let aiDailyLimit: Int
    }

    var usageStats: UsageStats {
        UsageStats(
            todayRecordings: 12,
            weekRecordings: 67,
            monthRecordings: 234,
            activeUsersToday: 8,
            aiUsageToday: 7,
            aiDailyLimit: currentOrganization?.plan.dailyAILimit ?? 10
        )
    }
}
