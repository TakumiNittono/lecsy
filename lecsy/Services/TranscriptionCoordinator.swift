//
//  TranscriptionCoordinator.swift
//  lecsy
//
//  リアルタイム字幕（Deepgram）と録音後 WhisperKit の役割分担を司る。
//
//  Pro (org member) フロー:
//    - 録音ボタンタップ → RecordView が `prepare()` を呼んで websocket 先行接続
//    - 接続完了後に RecordingService.startRecording() → `observeRecording` が isRecording=true を検知
//      → 既に prepared な session があればそれを使って即座に audio capture 開始
//    - 最初の発話から字幕が途切れなく出る
//
//  Free フロー: Deepgram は使わない（WhisperKit 録音後処理のみ）
//

import Foundation
import Combine
import Network

@MainActor
final class TranscriptionCoordinator: ObservableObject {

    static let shared = TranscriptionCoordinator()

    // MARK: - Published
    @Published private(set) var liveSegments: [DeepgramStreamSession.Segment] = []
    @Published private(set) var interimText: String = ""
    @Published private(set) var isLiveActive: Bool = false
    @Published private(set) var isPreparing: Bool = false
    @Published private(set) var liveError: String?

    // MARK: - Private
    private var stream: DeepgramStreamSession?
    private var capture: DeepgramAudioCapture?
    /// prepare() で先行接続した session。startLive() が呼ばれた時に再利用する。
    private var preparedSession: DeepgramStreamSession?
    /// preparedSession を張った時刻。古すぎる場合（>30s 放置）は作り直す。
    private var preparedAt: Date?
    private let preparedSessionMaxAge: TimeInterval = 30
    private var cancellables: Set<AnyCancellable> = []
    private var isOnline: Bool = true
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "lecsy.coordinator.network")

    private var captureStartRecordingOffset: TimeInterval = 0
    /// stopLive() が起こした flush 待ち Task。consumeFinalizedTranscript は
    /// これを await してから liveSegments を読むことで、Deepgram の最終 final を
    /// 取りこぼさない。
    private var pendingFlush: Task<Void, Never>?

    private init() {
        setupNetworkMonitor()
        observeRecording()
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Setup

    private func setupNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func observeRecording() {
        let rec = RecordingService.shared
        rec.$isRecording
            .removeDuplicates()
            .sink { [weak self] isRecording in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if isRecording {
                        await self.startLive()
                    } else {
                        self.stopLive()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public: preconnect for Pro users

    /// 録音ボタンが押された直後、実際に RecordingService.startRecording() を呼ぶ前に
    /// 呼ぶと Deepgram websocket を先に開いて準備を終える。Free / offline / 未認証は no-op。
    /// 失敗しても throw はしない（WhisperKit fallback で録音自体は続行できる）。
    func prepare() async {
        guard isOnline,
              AuthService.shared.isAuthenticated,
              PlanService.shared.isPaid else { return }

        // 既に進行中の prepare があれば重複しない
        guard !isPreparing else { return }

        // stream 使用中（録音中）なら何もしない
        guard stream == nil else { return }

        // 既に prepare 済だが古すぎる場合は破棄して張り直す
        if let existing = preparedSession, let at = preparedAt,
           Date().timeIntervalSince(at) > preparedSessionMaxAge {
            await existing.finish()
            preparedSession = nil
            preparedAt = nil
        }
        // 新鮮な preparedSession があればそのまま使う
        if preparedSession != nil { return }

        isPreparing = true
        defer { isPreparing = false }

        liveError = nil
        liveSegments = []
        interimText = ""

        let provider = DeepgramTokenProvider()
        var config = DeepgramStreamSession.Config()
        config.language = "multi"
        let session = DeepgramStreamSession(tokenProvider: provider, config: config)

        session.$finalizedSegments
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveSegments)
        session.$interimText
            .receive(on: DispatchQueue.main)
            .assign(to: &$interimText)

        do {
            try await session.connect()
            // 接続完了時点で既に録音が始まっていたら、そのまま startLive へハンドオフ
            if RecordingService.shared.isRecording && stream == nil {
                self.preparedSession = session
                self.preparedAt = Date()
                await startLive()
            } else {
                preparedSession = session
                preparedAt = Date()
            }
            AppLogger.info("Deepgram preconnected", category: .transcription)
        } catch {
            AppLogger.warning("Deepgram preconnect failed: \(error.localizedDescription)", category: .transcription)
            liveError = error.localizedDescription
        }
    }

    // MARK: - Lifecycle

    private func startLive() async {
        guard isOnline else { return }
        guard AuthService.shared.isAuthenticated else { return }
        guard PlanService.shared.isPaid else {
            AppLogger.info("Live caption skipped: free plan (using WhisperKit)", category: .transcription)
            return
        }
        // 二重起動ガード：すでに capture 中 or prepare 中なら何もしない
        guard stream == nil else { return }
        if isPreparing {
            // prepare が接続完了後に自分で startLive を呼ぶので、ここでは何もせず任せる
            AppLogger.info("Live caption deferred: prepare() in-flight", category: .transcription)
            return
        }

        // prepare() 済みなら再利用。そうでなければその場で接続（後方互換）
        let session: DeepgramStreamSession
        if let prepared = preparedSession {
            session = prepared
            preparedSession = nil
            preparedAt = nil
        } else {
            liveSegments = []
            interimText = ""
            liveError = nil

            let provider = DeepgramTokenProvider()
            var config = DeepgramStreamSession.Config()
            config.language = "multi"
            let newSession = DeepgramStreamSession(tokenProvider: provider, config: config)

            newSession.$finalizedSegments
                .receive(on: DispatchQueue.main)
                .assign(to: &$liveSegments)
            newSession.$interimText
                .receive(on: DispatchQueue.main)
                .assign(to: &$interimText)

            do {
                try await newSession.connect()
            } catch {
                AppLogger.warning("Deepgram connect failed: \(error.localizedDescription)", category: .transcription)
                liveError = error.localizedDescription
                return
            }
            session = newSession
        }

        self.stream = session
        isLiveActive = true

        let capture = DeepgramAudioCapture()
        capture.onChunk = { [weak session] data in
            session?.send(audio: data)
        }
        self.capture = capture

        do {
            try capture.start()
            captureStartRecordingOffset = RecordingService.shared.currentDuration
            AppLogger.info("Deepgram capture started at m4a offset \(captureStartRecordingOffset)s", category: .transcription)
        } catch {
            AppLogger.warning("Audio capture start failed: \(error.localizedDescription)", category: .transcription)
            liveError = error.localizedDescription
            stopLive()
        }
    }

    /// Deepgram から pending の final が flush されきるまで（最大1.5秒）待ってから切断する。
    /// RecordView は停止直後に TitleSheet を表示 → ユーザーがタイトル入力する間にこの flush が走る。
    /// consumeFinalizedTranscript はタイトル保存後に呼ばれるので、通常は flush 完了済みで読まれる。
    func stopLive() {
        capture?.stop()
        capture = nil
        isLiveActive = false

        let closingStream = stream
        let closingPrepared = preparedSession
        stream = nil
        preparedSession = nil
        preparedAt = nil

        pendingFlush?.cancel()
        pendingFlush = Task { @MainActor in
            await closingStream?.finish()
            await closingPrepared?.finish()
        }
    }

    // MARK: - Consume for persistence

    /// 録音終了後のトランスクリプト取り出し。Deepgram の最終 final flush を最大 1.5秒
    /// 待ってから読み取る。タイトル入力シート中にユーザーがすぐ保存したケースでも、
    /// flush 中のセグメントを取りこぼさないためのガード。
    func consumeFinalizedTranscript(processingTime: TimeInterval = 0) async -> TranscriptionResult? {
        await pendingFlush?.value
        pendingFlush = nil

        guard !liveSegments.isEmpty else { return nil }

        let offset = captureStartRecordingOffset
        let segments = liveSegments.map { seg in
            TranscriptionResult.TranscriptionSegment(
                startTime: seg.start + offset,
                endTime: seg.end + offset,
                text: seg.text
            )
        }

        let fullText = liveSegments
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let primaryLang = liveSegments.compactMap(\.language).first

        let result = TranscriptionResult(
            text: fullText,
            segments: segments,
            language: primaryLang,
            processingTime: processingTime
        )

        liveSegments = []
        interimText = ""
        captureStartRecordingOffset = 0

        return result
    }
}
