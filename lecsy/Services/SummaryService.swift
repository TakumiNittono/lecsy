//
//  SummaryService.swift
//  lecsy
//
//  AI 要約生成 (要サインイン)。フロー:
//    1. transcript content を save-transcript Edge Function でアップロード
//       → transcript_id を取得
//    2. summarize Edge Function を transcript_id で呼ぶ → 要約結果
//
//  iOS の transcript はローカルストレージなので、要約のためだけに
//  Supabase に行を作る (使い捨てではなく、後の cross-lecture summary
//  などのためにも使える)。
//
//  匿名ユーザー (skipped login) は使えない。呼び出し側で AuthService の
//  currentUser をチェックしてから呼ぶこと。
//

import Foundation

@MainActor
final class SummaryService {
    static let shared = SummaryService()
    private let sb = LecsyAPIClient.shared

    private init() {}

    enum SummaryMode: String {
        case summary
        case exam
    }

    /// API レスポンス。`summary` モードでは sections が、`exam` モードでは
    /// questions がそれぞれ埋まる (両方持っているのは Edge Function の都合)。
    struct SummaryResult: Decodable {
        let id: String?
        let transcript_id: String?
        let summary: String?
        let key_points: [String]?
        let sections: [Section]?
        let exam_mode: ExamMode?

        struct Section: Decodable, Identifiable {
            let heading: String
            let content: String
            var id: String { heading }
        }

        struct ExamMode: Decodable {
            let questions: [Question]?
        }

        struct Question: Decodable, Identifiable {
            let question: String
            let answer: String?
            var id: String { question }
        }
    }

    enum SummaryError: LocalizedError {
        case notSignedIn
        case uploadFailed(String)
        case summarizeFailed(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Please sign in to use AI summary."
            case .uploadFailed(let msg):
                return "Failed to upload transcript: \(msg)"
            case .summarizeFailed(let msg):
                return "Failed to generate summary: \(msg)"
            }
        }
    }

    /// transcript content をアップロード → 要約生成。
    /// outputLanguage: 'ja' / 'en' 等、要約結果の言語コード (省略時は 'ja')。
    func generateSummary(
        title: String,
        content: String,
        durationSeconds: Double?,
        language: String?,
        mode: SummaryMode = .summary,
        outputLanguage: String = "ja"
    ) async throws -> SummaryResult {
        guard AuthService.shared.currentUser != nil else {
            throw SummaryError.notSignedIn
        }

        // 1. アップロード
        struct SavePayload: Encodable {
            let title: String
            let content: String
            let created_at: String
            let duration: Double?
            let language: String?
        }
        struct SaveResp: Decodable {
            let id: String
            let created_at: String?
        }

        let savePayload = SavePayload(
            title: title,
            content: content,
            created_at: ISO8601DateFormatter().string(from: Date()),
            duration: durationSeconds,
            language: language
        )

        let saveResp: SaveResp
        do {
            saveResp = try await sb.invokeFunction("save-transcript", body: savePayload, timeout: 60)
        } catch {
            throw SummaryError.uploadFailed("\(error)")
        }

        // 2. 要約生成
        struct SummarizePayload: Encodable {
            let transcript_id: String
            let mode: String
            let output_language: String
        }
        let summarizePayload = SummarizePayload(
            transcript_id: saveResp.id,
            mode: mode.rawValue,
            output_language: outputLanguage
        )

        do {
            // gpt-4-turbo の要約は 30〜90 秒かかることがあるので長めに
            let result: SummaryResult = try await sb.invokeFunction("summarize", body: summarizePayload, timeout: 180)
            return result
        } catch {
            throw SummaryError.summarizeFailed("\(error)")
        }
    }
}
