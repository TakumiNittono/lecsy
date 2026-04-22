//
//  DeepgramStreamSession.swift
//  lecsy
//
//  Deepgram Nova-3 Streaming (WebSocket) クライアント。
//  依存: URLSessionWebSocketTask（iOS 13+標準）のみ。外部SDK不要。
//
//  参照: Deepgram/EXECUTION_PLAN.md W02
//       Deepgram/技術/Deepgram実装_単体版.md §6-7
//
//  ライフサイクル:
//    let session = DeepgramStreamSession(tokenProvider: DeepgramTokenProvider())
//    try await session.connect()
//    session.send(audio: pcm16Chunk)          // 16kHz mono little-endian
//    // @Published finalizedText / interimText を観察
//    session.finish()
//

import Foundation
import Combine

@MainActor
final class DeepgramStreamSession: ObservableObject {

    // MARK: - Published
    @Published private(set) var finalizedSegments: [Segment] = []
    @Published private(set) var interimText: String = ""
    @Published private(set) var connectionState: ConnectionState = .idle

    /// 確定したセグメント。Deepgram は `is_final=true` を細かい塊（数語〜1フレーズ）
    /// 単位で返してくるが、`speech_final=false` の間は「まだ発話が続いている」ので
    /// 同じ paragraph にまとめて表示する方が読みやすい。
    /// Merging は DeepgramStreamSession.parseResult で行い、ここでは単なる格納だけ。
    struct Segment: Identifiable, Equatable {
        var id = UUID()
        var text: String
        var start: Double
        var end: Double
        var language: String?
    }

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case closed(code: Int?)
        case failed(String)
    }

    // MARK: - Config
    struct Config {
        var model: String = "nova-3"
        var language: String = "multi"        // 多言語自動切替
        var sampleRate: Int = 16_000
        var encoding: String = "linear16"
        var channels: Int = 1
        var smartFormat: Bool = true
        var interimResults: Bool = true
        var endpointing: Int = 300            // 発話区切り閾値 ms
        var keyterms: [String] = []           // 専門用語ヒント
    }

    // MARK: - Private
    private let tokenProvider: DeepgramTokenProviderProtocol
    private let config: Config
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    /// finish() の flush 待ちループで使う。最後に final が届いた時刻。
    private var lastSegmentAt: Date?
    /// 直近の final が speech_final=false だったか。true の間は次の final を
    /// 末尾 segment に連結する（paragraph 形成）。speech_final=true で close。
    private var currentParagraphOpen: Bool = false

    init(
        tokenProvider: DeepgramTokenProviderProtocol,
        config: Config = .init(),
        urlSession: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.config = config
        self.urlSession = urlSession
    }

    // MARK: - Public API

    func connect() async throws {
        connectionState = .connecting
        reconnectAttempts = 0
        try await openSocket()
    }

    /// 16kHz mono linear PCM (Int16 LE) チャンクを送信
    func send(audio: Data) {
        guard let task else { return }
        task.send(.data(audio)) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.handleSocketError(error)
                }
            }
        }
    }

    /// 正常終了。Deepgramに`{"type":"CloseStream"}`を送ったあと、残りの interim を
    /// finalize して送り返してくるのを最大1.5秒待ってから切断する。
    /// ここを即時 cancel すると最後の1-2セグメントが落ちて、録音との突き合わせが欠ける。
    func finish() async {
        guard let task else { return }
        let close = #"{"type":"CloseStream"}"#
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            task.send(.string(close)) { _ in cont.resume() }
        }

        // flush 完了を検知する手段が無いので固定の grace period を置く。
        // Deepgram 経験則: CloseStream 後 200-800ms 以内に最終 Results / Metadata を
        // 送ってくる。1.5秒で打ち切る。
        let graceNanos: UInt64 = 1_500_000_000
        let flushStart = Date()
        let segmentsAtStart = finalizedSegments.count
        while Date().timeIntervalSince(flushStart) * 1_000_000_000 < Double(graceNanos) {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            // 新しい final が200ms間来なければ打ち切り（早期終了で UX 改善）
            if finalizedSegments.count > segmentsAtStart,
               let last = lastSegmentAt,
               Date().timeIntervalSince(last) > 0.2 {
                break
            }
        }

        // 残っている interim は final として採用する。発話の途中で stop した場合の救済。
        // paragraph 継続中なら末尾 segment に連結、そうでなければ新規 segment。
        if !interimText.isEmpty {
            if currentParagraphOpen, let lastIdx = finalizedSegments.indices.last {
                var extended = finalizedSegments[lastIdx]
                extended.text = joinParagraphText(existing: extended.text, new: interimText)
                finalizedSegments[lastIdx] = extended
            } else {
                finalizedSegments.append(
                    Segment(text: interimText, start: 0, end: 0, language: nil)
                )
            }
            interimText = ""
            currentParagraphOpen = false
        }

        self.task?.cancel(with: .normalClosure, reason: nil)
        cleanup(finalState: .closed(code: 1000))
    }

    // MARK: - Socket

    private func openSocket() async throws {
        let token: String
        do {
            token = try await tokenProvider.issueToken()
        } catch {
            connectionState = .failed(error.localizedDescription)
            throw error
        }

        var comps = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var items: [URLQueryItem] = [
            .init(name: "model",           value: config.model),
            .init(name: "language",        value: config.language),
            .init(name: "encoding",        value: config.encoding),
            .init(name: "sample_rate",     value: String(config.sampleRate)),
            .init(name: "channels",        value: String(config.channels)),
            .init(name: "smart_format",    value: config.smartFormat ? "true" : "false"),
            .init(name: "interim_results", value: config.interimResults ? "true" : "false"),
            .init(name: "endpointing",     value: String(config.endpointing)),
            .init(name: "vad_events",      value: "true"),
        ]
        for term in config.keyterms {
            items.append(.init(name: "keyterm", value: term))
        }
        comps.queryItems = items

        var req = URLRequest(url: comps.url!)
        req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15

        let task = urlSession.webSocketTask(with: req)
        self.task = task
        task.resume()

        connectionState = .connected
        startReceiveLoop()
        startKeepAlive()
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { @MainActor [weak self] in
            while let self, let task = self.task {
                if Task.isCancelled { return }
                do {
                    let message = try await task.receive()
                    if Task.isCancelled { return }
                    self.handleMessage(message)
                } catch {
                    if Task.isCancelled { return }
                    self.handleSocketError(error)
                    break
                }
            }
        }
    }

    /// 2段階 keep-alive:
    /// - **アプリ層 (5秒)**: Deepgram サーバが 10秒無音でセッション切るのを防ぐ
    ///   `{"type":"KeepAlive"}` JSON メッセージ
    /// - **WebSocket 層 (10秒)**: `sendPing()` で制御フレームを投げて NAT / VPN の
    ///   idle timeout 追跡を継続的に更新する。アプリ層データと違って VPN によっては
    ///   ping frame は別扱いになり、より確実に NAT テーブルを生かす
    /// どちらの send も失敗した時点で直ちに connection state を .failed に落として
    /// 上位 (TranscriptionCoordinator) の自動 reconnect に即繋ぐ。以前は swallow で
    /// receive 側が死ぬまで数秒ロスしていた。
    private func startKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { @MainActor [weak self] in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, let task = self.task else { return }

                // アプリ層 KeepAlive (毎 5秒)
                task.send(.string(#"{"type":"KeepAlive"}"#)) { [weak self] err in
                    if err != nil {
                        Task { @MainActor [weak self] in
                            self?.markFailedIfActive()
                        }
                    }
                }

                // WebSocket-level PING (10秒に1回 = 2 tick に 1回)
                tickCount += 1
                if tickCount.isMultiple(of: 2) {
                    task.sendPing { [weak self] err in
                        if err != nil {
                            Task { @MainActor [weak self] in
                                self?.markFailedIfActive()
                            }
                        }
                    }
                }
            }
        }
    }

    /// keep-alive / ping が失敗した時に、既に .failed でない connection state を
    /// failed に落として上位の reconnect ロジックを即発火させる。
    private func markFailedIfActive() {
        if case .failed = connectionState { return }
        if case .closed = connectionState { return }
        AppLogger.warning("Deepgram keep-alive / ping failed — marking stream as failed for reconnect", category: .transcription)
        connectionState = .failed("keep-alive send failed (likely VPN / NAT drop)")
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let s):
            parseResult(s)
        case .data(let d):
            if let s = String(data: d, encoding: .utf8) {
                parseResult(s)
            }
        @unknown default:
            break
        }
    }

    private func parseResult(_ json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Deepgram の標準 Results envelope
        guard (obj["type"] as? String) == "Results",
              let channel    = obj["channel"] as? [String: Any],
              let alts       = channel["alternatives"] as? [[String: Any]],
              let first      = alts.first,
              let transcript = first["transcript"] as? String,
              !transcript.isEmpty else {
            return
        }

        let isFinal     = (obj["is_final"]     as? Bool) ?? false
        let speechFinal = (obj["speech_final"] as? Bool) ?? false
        let start       = (obj["start"]    as? Double) ?? 0
        let duration    = (obj["duration"] as? Double) ?? 0

        // Deepgram `interim_results=true` のセマンティクス:
        //   is_final=false                      → interim（次のメッセージで置き換え）
        //   is_final=true,  speech_final=false  → 確定した1塊（発話継続中）
        //   is_final=true,  speech_final=true   → 確定 + 文末区切り
        //
        // UX 方針: speech_final=false の間は末尾 segment に連結して1つの paragraph
        // として表示する（ユーザーから見ると「文章として」続けて読める）。
        // speech_final=true で paragraph を closeし、次の final から新規 segment。
        if isFinal {
            let lang = (first["languages"] as? [String])?.first
            let wasEmpty = finalizedSegments.isEmpty

            if currentParagraphOpen, let lastIdx = finalizedSegments.indices.last {
                // 既存 paragraph に連結。id / start は保持、text を繋ぎ、end を伸ばす。
                var extended = finalizedSegments[lastIdx]
                extended.text = joinParagraphText(existing: extended.text, new: transcript)
                extended.end = start + duration
                if extended.language == nil, let lang { extended.language = lang }
                finalizedSegments[lastIdx] = extended
            } else {
                // 新しい paragraph 開始
                finalizedSegments.append(
                    Segment(text: transcript, start: start, end: start + duration, language: lang)
                )
            }

            // paragraph 継続フラグ更新
            currentParagraphOpen = !speechFinal

            interimText = ""
            lastSegmentAt = Date()
            if wasEmpty {
                AppLogger.info("Deepgram: first final segment received", category: .transcription)
            }
        } else {
            interimText = transcript
        }
    }

    /// 同じ paragraph 内で segment を繋ぐときの文字列結合。
    /// 日本語・中国語など CJK 言語は単語間スペース無し、それ以外はスペース区切り。
    private func joinParagraphText(existing: String, new: String) -> String {
        let trimmedNew = new.trimmingCharacters(in: .whitespaces)
        guard !trimmedNew.isEmpty else { return existing }
        let trimmedExisting = existing.trimmingCharacters(in: .whitespaces)
        guard !trimmedExisting.isEmpty else { return trimmedNew }

        // config.language が "ja" / "zh" なら space 無しで結合、それ以外は space
        let cjkLanguages: Set<String> = ["ja", "zh"]
        let separator = cjkLanguages.contains(config.language) ? "" : " "
        return trimmedExisting + separator + trimmedNew
    }

    private func handleSocketError(_ error: Error) {
        guard reconnectAttempts < maxReconnectAttempts else {
            cleanup(finalState: .failed(error.localizedDescription))
            return
        }

        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)

        let backoffMs = Int(pow(2.0, Double(reconnectAttempts))) * 500
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(backoffMs) * 1_000_000)
            guard let self else { return }
            do {
                try await self.openSocket()
            } catch {
                self.cleanup(finalState: .failed(error.localizedDescription))
            }
        }
    }

    private func cleanup(finalState: ConnectionState) {
        receiveTask?.cancel()
        keepAliveTask?.cancel()
        task = nil
        connectionState = finalState
    }
}
