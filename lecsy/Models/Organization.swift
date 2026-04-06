//
//  Organization.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import Foundation

// MARK: - Organization Role

enum OrganizationRole: String, Codable, CaseIterable, Comparable {
    case student
    case teacher
    case admin
    case owner

    var displayName: String {
        switch self {
        case .student: return "Student"
        case .teacher: return "Teacher"
        case .admin: return "Admin"
        case .owner: return "Owner"
        }
    }

    var icon: String {
        switch self {
        case .student: return "person.fill"
        case .teacher: return "person.badge.key.fill"
        case .admin: return "person.badge.shield.checkmark.fill"
        case .owner: return "crown.fill"
        }
    }

    /// Permission level for comparison
    private var level: Int {
        switch self {
        case .student: return 0
        case .teacher: return 1
        case .admin: return 2
        case .owner: return 3
        }
    }

    static func < (lhs: OrganizationRole, rhs: OrganizationRole) -> Bool {
        lhs.level < rhs.level
    }

    var canManageMembers: Bool { self >= .admin }
    var canManageClasses: Bool { self >= .teacher }
    var canGenerateGlossary: Bool { self >= .teacher }
    var canViewUsageStats: Bool { self >= .teacher }
    var canChangeOrgSettings: Bool { self >= .admin }
    var canManageBilling: Bool { self >= .admin }
    var canDeleteOrg: Bool { self == .owner }
}

// MARK: - Organization Plan

enum OrganizationPlan: String, Codable, CaseIterable {
    case starter
    case growth
    case enterprise

    var displayName: String {
        switch self {
        case .starter: return "Starter"
        case .growth: return "Growth"
        case .enterprise: return "Enterprise"
        }
    }

    var dailyAILimit: Int {
        switch self {
        case .starter: return 10
        case .growth: return 50
        case .enterprise: return 200
        }
    }

    var monthlyPrice: String {
        switch self {
        case .starter: return "$299"
        case .growth: return "$599"
        case .enterprise: return "Custom"
        }
    }
}

// MARK: - Organization Type

enum OrganizationType: String, Codable, CaseIterable {
    case languageSchool = "language_school"
    case universityIEP = "university_iep"
    case college
    case corporate

    var displayName: String {
        switch self {
        case .languageSchool: return "Language School"
        case .universityIEP: return "University IEP"
        case .college: return "College"
        case .corporate: return "Corporate"
        }
    }
}

// MARK: - Member Status

enum MemberStatus: String, Codable {
    case pending
    case active
    case removed
}

// MARK: - Recording Visibility

enum RecordingVisibility: String, Codable {
    case `private`
    case shared
    case orgWide = "org_wide"

    var displayName: String {
        switch self {
        case .private: return "Private"
        case .shared: return "Shared (Class)"
        case .orgWide: return "Organization"
        }
    }

    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .shared: return "person.2.fill"
        case .orgWide: return "building.2.fill"
        }
    }
}

// MARK: - Organization

struct Organization: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var slug: String
    var type: OrganizationType
    var plan: OrganizationPlan
    var maxSeats: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        slug: String,
        type: OrganizationType = .languageSchool,
        plan: OrganizationPlan = .starter,
        maxSeats: Int = 50,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.type = type
        self.plan = plan
        self.maxSeats = maxSeats
        self.createdAt = createdAt
    }
}

// MARK: - Organization Member

struct OrganizationMember: Identifiable, Codable, Equatable {
    let id: UUID
    let organizationId: UUID
    var userId: UUID?
    var email: String
    var displayName: String
    var role: OrganizationRole
    var status: MemberStatus
    let joinedAt: Date

    init(
        id: UUID = UUID(),
        organizationId: UUID,
        userId: UUID? = nil,
        email: String,
        displayName: String,
        role: OrganizationRole = .student,
        status: MemberStatus = .pending,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.role = role
        self.status = status
        self.joinedAt = joinedAt
    }
}

// MARK: - Organization Class

struct OrganizationClass: Identifiable, Codable, Equatable {
    let id: UUID
    let organizationId: UUID
    var name: String
    var language: TranscriptionLanguage
    var semester: String
    var teacherId: UUID?
    var studentIds: [UUID]

    init(
        id: UUID = UUID(),
        organizationId: UUID,
        name: String,
        language: TranscriptionLanguage = .english,
        semester: String = "",
        teacherId: UUID? = nil,
        studentIds: [UUID] = []
    ) {
        self.id = id
        self.organizationId = organizationId
        self.name = name
        self.language = language
        self.semester = semester
        self.teacherId = teacherId
        self.studentIds = studentIds
    }
}

// MARK: - Glossary Entry

struct GlossaryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let organizationId: UUID
    var term: String
    var definition: String
    var example: String
    var targetLanguage: TranscriptionLanguage
    var translation: String
    var difficulty: DifficultyLevel
    let createdAt: Date

    enum DifficultyLevel: String, Codable, CaseIterable {
        case beginner
        case intermediate
        case advanced

        var displayName: String {
            switch self {
            case .beginner: return "Beginner"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            }
        }

        var color: String {
            switch self {
            case .beginner: return "green"
            case .intermediate: return "orange"
            case .advanced: return "red"
            }
        }
    }

    init(
        id: UUID = UUID(),
        organizationId: UUID,
        term: String,
        definition: String,
        example: String = "",
        targetLanguage: TranscriptionLanguage = .spanish,
        translation: String = "",
        difficulty: DifficultyLevel = .intermediate,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.term = term
        self.definition = definition
        self.example = example
        self.targetLanguage = targetLanguage
        self.translation = translation
        self.difficulty = difficulty
        self.createdAt = createdAt
    }
}
