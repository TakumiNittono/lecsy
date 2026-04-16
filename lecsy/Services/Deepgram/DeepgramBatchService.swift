//
//  DeepgramBatchService.swift
//  lecsy
//
//  録音済音声ファイル(.m4a等)を Deepgram Prerecorded API へ送って文字起こしする。
//  ライブ字幕(streaming)が動けなかった/失敗した時のpost-processing用。
//
//  参照: Deepgram/EXECUTION_PLAN.md W05 Phase 2
//

import Foundation

enum DeepgramBatchError: Error, LocalizedError {
    case tokenFailed(Error)
    case fileMissing
    case fileTooLarge(Int)
    case network(Int)
    case decodeFailed
    case empty

    var errorDescription: String? {
        switch self {
        case .tokenFailed(let e):     return "Auth failed: \(e.localizedDescription)"
        case .fileMissing:            return "Audio file not found"
        case .fileTooLarge(let n):    return "Audio too large: \(n / (1024*1024))MB"
        case .network(let code):      return "Deepgram error \(code)"
        case .decodeFailed:           return "Failed to parse Deepgram response"
        case .empty:                  return "Deepgram returned empty transcript"
        }
    }
}

@MainActor
final class DeepgramBatchService {

    static let shared = DeepgramBatchService(tokenProvider: DeepgramTokenProvider.nonisolatedMakeDefault())

    private let tokenProvider: DeepgramTokenProviderProtocol
    private let session: URLSession

    /// 上限: 100MB（Deepgramドキュメント上は2GBだが、モバイルでこれ以上はネットワーク負荷大）
    private let maxFileSizeBytes = 100 * 1024 * 1024

    nonisolated init(
        tokenProvider: DeepgramTokenProviderProtocol,
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600    // 10分（長尺音声）
        config.timeoutIntervalForResource = 1200
        self.session = URLSession(configuration: config)
        _ = session
    }

    /// デフォルト依存で初期化する便利初期化子。MainActor前提。
    @MainActor
    convenience init() {
        self.init(tokenProvider: DeepgramTokenProvider())
    }

    // MARK: - Public

    /// 音声ファイル → Deepgram Nova-3 多言語 → TranscriptionResult
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw DeepgramBatchError.fileMissing
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        if size > maxFileSizeBytes {
            throw DeepgramBatchError.fileTooLarge(size)
        }

        let token: String
        do {
            token = try await tokenProvider.issueToken()
        } catch {
            throw DeepgramBatchError.tokenFailed(error)
        }

        var comps = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        comps.queryItems = [
            .init(name: "model",        value: "nova-3"),
            .init(name: "language",     value: "multi"),
            .init(name: "smart_format", value: "true"),
            .init(name: "punctuate",    value: "true"),
            .init(name: "diarize",      value: "false"),
            .init(name: "utterances",   value: "true"),
            .init(name: "paragraphs",   value: "true"),
        ]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(mimeType(for: audioURL), forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600

        // URLSession.upload(for:from:) は upload task を作るため、req.httpBody を
        // セットすると CFNetwork -994 "should not contain a body" で即失敗する。
        // body は from: 引数だけで渡す。
        let bodyData = try Data(contentsOf: audioURL)

        let started = Date()
        let (data, response) = try await URLSession.shared.upload(
            for: req,
            from: bodyData
        )

        guard let http = response as? HTTPURLResponse else {
            throw DeepgramBatchError.network(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLogger.warning("Deepgram batch HTTP \(http.statusCode): \(body.prefix(200))", category: .transcription)
            throw DeepgramBatchError.network(http.statusCode)
        }

        return try parse(data: data, processingTime: Date().timeIntervalSince(started))
    }

    // MARK: - Parsing

    private func parse(data: Data, processingTime: TimeInterval) throws -> TranscriptionResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [String: Any] else {
            throw DeepgramBatchError.decodeFailed
        }

        // utterances ベースで TranscriptionSegment を組み立てる（タイムコード保持）
        var segments: [TranscriptionResult.TranscriptionSegment] = []
        if let utterances = results["utterances"] as? [[String: Any]] {
            for u in utterances {
                let start = (u["start"]      as? Double) ?? 0
                let end   = (u["end"]        as? Double) ?? 0
                let text  = (u["transcript"] as? String) ?? ""
                if !text.isEmpty {
                    segments.append(.init(startTime: start, endTime: end, text: text))
                }
            }
        }

        // フルテキスト
        var fullText = ""
        if let channels = results["channels"] as? [[String: Any]],
           let alts = channels.first?["alternatives"] as? [[String: Any]],
           let transcript = alts.first?["transcript"] as? String {
            fullText = transcript
        } else if !segments.isEmpty {
            fullText = segments.map(\.text).joined(separator: " ")
        }

        if fullText.isEmpty && segments.isEmpty {
            throw DeepgramBatchError.empty
        }

        // 主言語検出
        var language: String?
        if let channels = results["channels"] as? [[String: Any]],
           let alts = channels.first?["alternatives"] as? [[String: Any]],
           let detected = alts.first?["languages"] as? [String] {
            language = detected.first
        }

        return TranscriptionResult(
            text: fullText,
            segments: segments,
            language: language,
            processingTime: processingTime
        )
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a", "aac": return "audio/aac"
        case "mp3":        return "audio/mpeg"
        case "wav":        return "audio/wav"
        case "flac":       return "audio/flac"
        case "ogg", "oga": return "audio/ogg"
        case "webm":       return "audio/webm"
        default:           return "application/octet-stream"
        }
    }
}
