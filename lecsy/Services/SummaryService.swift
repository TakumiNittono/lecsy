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
    struct SummaryResult: Codable, Equatable {
        let id: String?
        let transcript_id: String?
        let summary: String?
        let key_points: [String]?
        let sections: [Section]?
        let exam_mode: ExamMode?

        struct Section: Codable, Identifiable, Equatable {
            let heading: String
            let content: String
            var id: String { heading }
        }

        struct ExamMode: Codable, Equatable {
            let questions: [Question]?
        }

        struct Question: Codable, Identifiable, Equatable {
            let question: String
            let answer: String?
            var id: String { question }
        }
    }

    enum SummaryError: LocalizedError {
        case notSignedIn
        case uploadFailed(_ raw: String)
        case summarizeFailed(_ raw: String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Please sign in to use AI summary."
            case .uploadFailed:
                return "Failed to save transcript. Please check your connection and try again."
            case .summarizeFailed(let msg):
                return Self.userFriendlyMessage(from: msg)
            }
        }

        private static func userFriendlyMessage(from raw: String) -> String {
            if raw.contains("NSURLErrorDomain") || raw.contains("connection was lost") || raw.contains("timed out") || raw.contains("not connected") {
                return "Network error — please check your connection and try again."
            }
            if raw.contains("401") || raw.contains("403") {
                return "Session expired. Please sign out and sign in again."
            }
            if raw.contains("429") || raw.contains("rate") {
                return "Too many requests — please wait a moment and try again."
            }
            if raw.contains("500") || raw.contains("502") || raw.contains("503") {
                return "Server is temporarily unavailable. Please try again in a few minutes."
            }
            return "Failed to generate summary. Please try again."
        }
    }

    /// transcript content をアップロード → 要約生成。
    /// outputLanguage: 'en' / 'ja' 等、要約結果の言語コード (省略時は 'en' = FMCC パイロット想定)。
    func generateSummary(
        title: String,
        content: String,
        durationSeconds: Double?,
        language: String?,
        mode: SummaryMode = .summary,
        outputLanguage: String = "en"
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

    // MARK: - Streaming summary

    /// Streaming variant. Yields the accumulated raw markdown text as it
    /// arrives so the UI can display partial output. On `finished` the
    /// caller receives the fully parsed `SummaryResult`.
    enum StreamEvent {
        case partialText(String)      // full accumulated markdown so far
        case finished(SummaryResult)  // parsed structured result
    }

    func streamSummary(
        title: String,
        content: String,
        durationSeconds: Double?,
        language: String?,
        outputLanguage: String = "en"
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard AuthService.shared.currentUser != nil else {
                    continuation.finish(throwing: SummaryError.notSignedIn)
                    return
                }

                struct Payload: Encodable {
                    let content: String
                    let title: String
                    let language: String?
                    let output_language: String
                }
                let payload = Payload(
                    content: content,
                    title: title,
                    language: language,
                    output_language: outputLanguage
                )

                var accumulated = ""
                do {
                    let stream = sb.streamFunction("summarize-stream", body: payload, timeout: 180)
                    for try await chunk in stream {
                        accumulated += chunk
                        continuation.yield(.partialText(accumulated))
                    }
                    let parsed = parseStreamedMarkdown(accumulated)
                    continuation.yield(.finished(parsed))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: SummaryError.summarizeFailed("\(error)"))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Parse the streamed markdown format into a SummaryResult.
    ///   ## Summary
    ///   <paragraph>
    ///
    ///   ## Key Points
    ///   - point
    ///
    ///   ## Sections
    ///   ### heading
    ///   content
    func parseStreamedMarkdown(_ text: String) -> SummaryResult {
        let lines = text.components(separatedBy: "\n")
        enum Mode { case none, summary, keyPoints, sections }
        var mode: Mode = .none
        var summaryBuf: [String] = []
        var keyPoints: [String] = []
        var sections: [SummaryResult.Section] = []
        var currentSectionHeading: String?
        var currentSectionContent: [String] = []

        func flushSection() {
            if let h = currentSectionHeading {
                let content = currentSectionContent.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sections.append(SummaryResult.Section(heading: h, content: content))
            }
            currentSectionHeading = nil
            currentSectionContent = []
        }

        // Header aliases so we still parse correctly if the model translates
        // the section markers into the output language (e.g. "## 要約").
        let summaryAliases = ["summary", "要約", "overview", "概要", "resumen", "resumé", "résumé", "zusammenfassung", "摘要", "요약"]
        let keyPointsAliases = ["key points", "重要ポイント", "要点", "main points", "pontos-chave", "puntos clave", "points clés", "kernpunkte", "요점", "要点"]
        let sectionsAliases = ["sections", "セクション", "章", "secciones", "abschnitte", "部分", "섹션"]

        func matchesHeader(_ line: String, aliases: [String]) -> Bool {
            guard line.hasPrefix("##") else { return false }
            let stripped = line.dropFirst(2).trimmingCharacters(in: .whitespaces).lowercased()
            for alias in aliases {
                if stripped.hasPrefix(alias.lowercased()) {
                    return true
                }
            }
            return false
        }

        for rawLine in lines {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if matchesHeader(trimmed, aliases: summaryAliases) {
                flushSection()
                mode = .summary
                continue
            }
            if matchesHeader(trimmed, aliases: keyPointsAliases) {
                flushSection()
                mode = .keyPoints
                continue
            }
            if matchesHeader(trimmed, aliases: sectionsAliases) {
                flushSection()
                mode = .sections
                continue
            }
            switch mode {
            case .summary:
                if !trimmed.isEmpty { summaryBuf.append(trimmed) }
            case .keyPoints:
                if trimmed.hasPrefix("- ") || trimmed.hasPrefix("・") || trimmed.hasPrefix("* ") {
                    let bullet = trimmed
                        .drop(while: { "-・* ".contains($0) })
                    let text = String(bullet).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty { keyPoints.append(text) }
                } else if !trimmed.isEmpty && !keyPoints.isEmpty {
                    // Continuation of previous bullet
                    keyPoints[keyPoints.count - 1] += " " + trimmed
                }
            case .sections:
                if trimmed.hasPrefix("### ") {
                    flushSection()
                    currentSectionHeading = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                } else if !trimmed.isEmpty {
                    currentSectionContent.append(trimmed)
                }
            case .none:
                break
            }
        }
        flushSection()

        let summary = summaryBuf.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return SummaryResult(
            id: nil,
            transcript_id: nil,
            summary: summary.isEmpty ? nil : summary,
            key_points: keyPoints.isEmpty ? nil : keyPoints,
            sections: sections.isEmpty ? nil : sections,
            exam_mode: nil
        )
    }
}
