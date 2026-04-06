//
//  Organization.swift
//  lecsy
//
//  B2B組織関連のモデル定義
//

import Foundation

/// 組織情報
struct Organization: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let slug: String
    let type: String    // language_school, university_iep, college, corporate
    let plan: String    // starter, growth, enterprise
    let maxSeats: Int

    enum CodingKeys: String, CodingKey {
        case id, name, slug, type, plan
        case maxSeats = "max_seats"
    }
}

/// 組織メンバーシップ
struct OrgMembership: Codable, Equatable {
    let orgId: UUID
    let userId: UUID?
    let role: OrgRole
    let status: String  // "active" or "pending"
    let organization: Organization

    enum CodingKeys: String, CodingKey {
        case orgId = "org_id"
        case userId = "user_id"
        case role
        case status
        case organization = "organizations"
    }
}

/// 組織内のロール
enum OrgRole: String, Codable, Comparable {
    case student
    case teacher
    case admin
    case owner

    private var level: Int {
        switch self {
        case .student: return 1
        case .teacher: return 2
        case .admin: return 3
        case .owner: return 4
        }
    }

    static func < (lhs: OrgRole, rhs: OrgRole) -> Bool {
        lhs.level < rhs.level
    }
}

/// 組織用語集の用語
struct GlossaryTerm: Codable, Identifiable, Equatable {
    let id: UUID
    let orgId: UUID
    let term: String
    let definition: String
    let language: String
    let category: String?
    let sourceTranscriptId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orgId = "org_id"
        case term, definition, language, category
        case sourceTranscriptId = "source_transcript_id"
        case createdAt = "created_at"
    }
}

/// クロス要約の結果
struct CrossSummaryResult: Codable, Equatable {
    let summary: String
    let keyPoints: [String]
    let sections: [SummarySection]
    let sourceLanguage: String
    let targetLanguage: String
    let keyTermsBilingual: [BilingualTerm]?

    enum CodingKeys: String, CodingKey {
        case summary
        case keyPoints = "key_points"
        case sections
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case keyTermsBilingual = "key_terms_bilingual"
    }

    struct SummarySection: Codable, Equatable {
        let heading: String
        let content: String
    }

    struct BilingualTerm: Codable, Identifiable, Equatable {
        var id: String { "\(original)-\(translated)" }
        let original: String
        let translated: String
        let context: String?

        private enum CodingKeys: String, CodingKey {
            case original, translated, context
        }
    }
}

/// クロス要約のローカルキャッシュ
struct CachedCrossSummary: Codable, Identifiable, Equatable {
    var id: String { "\(transcriptId)-\(targetLanguage)" }
    let transcriptId: UUID
    let targetLanguage: String
    let result: CrossSummaryResult
    let cachedAt: Date

    private enum CodingKeys: String, CodingKey {
        case transcriptId = "transcript_id"
        case targetLanguage = "target_language"
        case result
        case cachedAt = "cached_at"
    }
}
