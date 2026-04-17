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

    /// 確定した1文（Deepgramの`is_final` && `speech_final`）
    struct Segment: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let start: Double
        let end: Double
        let language: String?
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
        if !interimText.isEmpty {
            finalizedSegments.append(
                .init(text: interimText, start: 0, end: 0, language: nil)
            )
            interimText = ""
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

    /// Deepgramは10秒以上音声が無いとタイムアウトする。
    /// 無音時用に5秒ごとに `{"type":"KeepAlive"}` を送る。
    private func startKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, let task = self.task else { return }
                task.send(.string(#"{"type":"KeepAlive"}"#), completionHandler: { _ in })
            }
        }
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
        //   is_final=false                → interim（次のメッセージで置き換えられる）
        //   is_final=true,  speech_final=false → 確定した1塊（まだ発話継続中）
        //   is_final=true,  speech_final=true  → 確定 + 文末区切り
        // 以前は `is_final && speech_final` だけ追加していて、speech_final=false の
        // 確定セグメントが丸ごと捨てられていた（=録音の中盤が抜ける現象）。
        // is_final=true ならすべて保存する。speech_final はここでは使わない。
        _ = speechFinal
        if isFinal {
            let lang = (first["languages"] as? [String])?.first
            let wasEmpty = finalizedSegments.isEmpty
            finalizedSegments.append(
                .init(text: transcript, start: start, end: start + duration, language: lang)
            )
            interimText = ""
            lastSegmentAt = Date()
            if wasEmpty {
                AppLogger.info("Deepgram: first final segment received", category: .transcription)
            }
        } else {
            interimText = transcript
        }
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
