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
import UIKit

@MainActor
final class TranscriptionCoordinator: ObservableObject {

    static let shared = TranscriptionCoordinator()

    // MARK: - Published
    @Published private(set) var liveSegments: [DeepgramStreamSession.Segment] = []
    @Published private(set) var interimText: String = ""
    @Published private(set) var isLiveActive: Bool = false
    @Published private(set) var isPreparing: Bool = false
    @Published private(set) var liveError: String?
    /// 再接続試行中。UI が「再接続中...」バナーを出せるよう公開。
    @Published private(set) var isReconnectingLive: Bool = false

    // MARK: - Private
    private var stream: DeepgramStreamSession?
    private var capture: DeepgramAudioCapture?
    /// prepare() で先行接続した session。startLive() が呼ばれた時に再利用する。
    private var preparedSession: DeepgramStreamSession?
    /// preparedSession を張った時刻。古すぎる場合（>30s 放置）は作り直す。
    private var preparedAt: Date?
    /// preparedSession を張った時の言語コード。ユーザーが録音直前に言語を切り替えた場合は破棄して張り直す。
    private var preparedLanguage: String?
    /// preparedSession の有効期限。ログイン時に preconnect して暫く放置されてから
    /// 録音開始するケースでも再接続を挟まず即 capture 開始できるよう、
    /// KeepAlive で維持できる範囲（5分）で保持する。期限超過は stale として再接続。
    private let preparedSessionMaxAge: TimeInterval = 5 * 60
    private var cancellables: Set<AnyCancellable> = []
    private var isOnline: Bool = true
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "lecsy.coordinator.network")

    private var captureStartRecordingOffset: TimeInterval = 0
    /// stopLive() が起こした flush 待ち Task。consumeFinalizedTranscript は
    /// これを await してから liveSegments を読むことで、Deepgram の最終 final を
    /// 取りこぼさない。
    private var pendingFlush: Task<Void, Never>?
    /// startLive の connect 中フラグ。prepare と startLive の二重接続を防ぐ。
    private var isStartingLive: Bool = false
    /// アクティブ stream の connectionState 観察用。stream 差し替え時に作り直す。
    private var streamStateSubscription: AnyCancellable?
    /// アクティブ stream の finalizedSegments 観察用（絶対時刻への変換用 sink）。
    private var streamSegmentsSubscription: AnyCancellable?
    /// アクティブ stream の interimText 観察用。
    private var streamInterimSubscription: AnyCancellable?
    /// 現行 session の「音声ファイル上の開始位置」（秒）。reconnect 時に更新。
    /// 再接続後の Deepgram segment の相対時刻にこの値を足して絶対時刻に直す。
    private var currentSessionOffset: TimeInterval = 0
    /// 過去の session から来た segment を絶対時刻に直した累積。
    /// reconnect 直前に現行 session の finalizedSegments を絶対時刻化して詰めておく。
    private var archivedSegments: [DeepgramStreamSession.Segment] = []
    /// 再接続 Task。重複起動を防ぐ。
    private var reconnectTask: Task<Void, Never>?
    /// 連続失敗回数。上限に達したら再接続を諦めて batch fallback に委ねる。
    private var reconnectConsecutiveFailures: Int = 0
    private let reconnectMaxAttempts: Int = 3
    /// 最後に live session を張った時刻。長時間録音で proactive recycle する基準。
    private var streamStartedAt: Date?
    private var proactiveRecycleTask: Task<Void, Never>?
    /// Session を何分で proactive recycle するか。Deepgram トークン期限（1h = TTL 900秒
    /// を内部でリフレッシュ）に対し、90分講義途中でのリフレッシュ失敗リスクを減らすため
    /// 45分で recycle する。50分だとリフレッシュが間に合わず sequence の中で失敗すると
    /// 字幕が一瞬途切れる観測があったため、余裕を 15分確保する。
    private let proactiveRecycleInterval: TimeInterval = 45 * 60

    private init() {
        setupNetworkMonitor()
        observeRecording()
        observeAppLifecycle()
        observeAuthAndPlan()
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Setup

    private func setupNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = (path.status == .satisfied)
                // オフライン→オンライン復帰で録音継続中なら stream を張り直す
                if wasOffline && self.isOnline && self.capture != nil {
                    // 新しい接続窓口が開いたので、失敗カウンタをリセット
                    self.reconnectConsecutiveFailures = 0
                    self.triggerReconnectIfNeeded(reason: "network recovered")
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    /// 認証 + Pro プラン判定の両方が確定したタイミングで Deepgram websocket を
    /// 事前接続する。RecordView.onAppear まで待たずに「ログインした瞬間から録音即スタート」
    /// できる UX にするため。
    ///
    /// - AuthService.$currentUser と PlanService.$currentPlan を購読
    /// - combineLatest で両方の最新値を監視
    /// - authenticated かつ isPaid になった時のみ prepare() を発火
    /// - prepare() 自身が二重起動 / 既 prepared / 録音中 / offline 等の gate を持つので
    ///   余剰発火しても安全（no-op で返る）
    private func observeAuthAndPlan() {
        AuthService.shared.$currentUser
            .map { $0 != nil }
            .removeDuplicates()
            .combineLatest(
                PlanService.shared.$currentPlan
                    .map { $0 == .pro }
                    .removeDuplicates()
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isAuthed, isPro) in
                guard let self else { return }
                guard isAuthed, isPro else { return }
                // 既に session が動いている / 準備中なら prepare() 側の gate で弾かれる
                Task { @MainActor [weak self] in
                    await self?.prepare()
                }
            }
            .store(in: &cancellables)
    }

    /// App が前景復帰した時、stream が死んでいたら再接続を試みる。
    /// 長い backgrounding で WebSocket が OS に切られているケース対策。
    private func observeAppLifecycle() {
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.capture != nil else { return }
                    // 前景復帰は「新しいチャンス」としてカウンタリセット
                    self.reconnectConsecutiveFailures = 0
                    if let stream = self.stream {
                        if case .failed = stream.connectionState {
                            self.triggerReconnectIfNeeded(reason: "app foregrounded, stream failed")
                        } else if case .closed = stream.connectionState {
                            self.triggerReconnectIfNeeded(reason: "app foregrounded, stream closed")
                        }
                    } else if self.isLiveActive {
                        // 異常系: stream が nil なのに live 扱い
                        self.triggerReconnectIfNeeded(reason: "app foregrounded, no stream")
                    }
                }
            }
            .store(in: &cancellables)
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

        // 既に進行中の prepare / startLive があれば重複しない
        guard !isPreparing, !isStartingLive else { return }

        // stream 使用中（録音中）なら何もしない
        guard stream == nil else { return }

        // 既に prepare 済だが古すぎる / ユーザーが言語を切り替えた場合は破棄して張り直す
        if let existing = preparedSession, let at = preparedAt {
            let currentLang = TranscriptionService.shared.transcriptionLanguage.deepgramCode
            let stale = Date().timeIntervalSince(at) > preparedSessionMaxAge
            let langChanged = preparedLanguage != currentLang
            if stale || langChanged {
                await existing.finish()
                preparedSession = nil
                preparedAt = nil
                preparedLanguage = nil
            }
        }
        // 新鮮な preparedSession があればそのまま使う
        if preparedSession != nil { return }

        isPreparing = true

        liveError = nil
        liveSegments = []
        interimText = ""

        // await を挟むので、connect 直前の言語を使う（prepare 途中に切替が起きても追従）
        let userLang = TranscriptionService.shared.transcriptionLanguage.deepgramCode
        let session = makeSession(language: userLang)

        do {
            try await session.connect()
            // connect() は await するので、その間に startLive が別の経路で
            // stream を立ち上げている可能性がある（PlanService.refresh と
            // RecordView.onAppear が近い時刻で prepare を呼ぶケース）。
            // その場合は今 connect した session を捨てて orphan を残さない。
            if stream != nil {
                await session.finish()
                isPreparing = false
                return
            }
            preparedSession = session
            preparedAt = Date()
            preparedLanguage = userLang
            AppLogger.info("Deepgram preconnected (lang: \(userLang))", category: .transcription)
        } catch {
            AppLogger.warning("Deepgram preconnect failed: \(error.localizedDescription)", category: .transcription)
            liveError = liveConnectFailureMessage(for: error)
            isPreparing = false
            return
        }

        // isPreparing をクリアしてから handoff しないと、startLive の
        // `if isPreparing { return }` で弾かれる。
        isPreparing = false

        // prepare 中にユーザーが録音ボタンを押して isRecording=true に
        // なっていたら、そのまま startLive にハンドオフする。
        if RecordingService.shared.isRecording && stream == nil && !isStartingLive {
            await startLive()
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
        // 二重起動ガード：すでに capture 中 / prepare 中 / 別の startLive が connect 中なら何もしない
        guard stream == nil else { return }
        if isPreparing {
            // prepare が完了次第、自分で handoff してくれる
            AppLogger.info("Live caption deferred: prepare() in-flight", category: .transcription)
            return
        }
        guard !isStartingLive else {
            AppLogger.info("Live caption deferred: another startLive in flight", category: .transcription)
            return
        }

        isStartingLive = true

        let userLang = TranscriptionService.shared.transcriptionLanguage.deepgramCode

        // prepare() 済みなら再利用。ただしその間にユーザーが言語を切替えていた場合は
        // 破棄して新規接続（preconnect の時は en、録音開始時は ja といったレースを吸収）。
        let session: DeepgramStreamSession
        if let prepared = preparedSession, preparedLanguage == userLang {
            session = prepared
            preparedSession = nil
            preparedAt = nil
            preparedLanguage = nil
            // 新しい録音の始まりなので、前回録音の残骸をクリア
            liveSegments = []
            interimText = ""
            archivedSegments = []
            liveError = nil
        } else {
            // prepared がある場合は言語不一致 → 捨てる
            if let stale = preparedSession {
                AppLogger.info("Deepgram: discarding prepared session — language mismatch (prepared=\(preparedLanguage ?? "?"), current=\(userLang))", category: .transcription)
                Task { @MainActor in await stale.finish() }
                preparedSession = nil
                preparedAt = nil
                preparedLanguage = nil
            }

            liveSegments = []
            interimText = ""
            archivedSegments = []
            liveError = nil

            let newSession = makeSession(language: userLang)

            do {
                try await newSession.connect()
            } catch {
                AppLogger.warning("Deepgram connect failed: \(error.localizedDescription)", category: .transcription)
                liveError = liveConnectFailureMessage(for: error)
                isStartingLive = false
                return
            }
            session = newSession
        }

        installStream(session)
        isLiveActive = true
        isStartingLive = false
        reconnectConsecutiveFailures = 0

        let capture = DeepgramAudioCapture()
        // onChunk は MainActor 経由で呼ばれる（DeepgramAudioCapture 側で Task { @MainActor } されている）。
        // 再接続で stream が差し替わっても動くよう、キャプチャ時 session 固定ではなく self.stream を都度参照する。
        capture.onChunk = { [weak self] data in
            self?.stream?.send(audio: data)
        }
        capture.onSilenceFailure = { [weak self] in
            guard let self else { return }
            self.liveError = "Live captions stopped because no microphone input was detected. Recording will continue and the audio will be transcribed after you stop."
            self.stopLive()
        }
        self.capture = capture

        do {
            try capture.start()
            captureStartRecordingOffset = RecordingService.shared.currentDuration
            // 最初の session の segment も正しい音声ファイル位置基準になるよう、
            // capture 起動後の録音ファイル位置を session offset として採用する。
            currentSessionOffset = captureStartRecordingOffset
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
        isReconnectingLive = false

        streamStateSubscription?.cancel()
        streamStateSubscription = nil
        // streamSegmentsSubscription / streamInterimSubscription は cancel しない。
        // stopLive 後も session.finish() の flush で追加 final が届くので、
        // liveSegments に反映させる必要がある。subscription は次回 installStream
        // で置き換えられる（または TranscriptionCoordinator 解放で自動停止）。
        reconnectTask?.cancel()
        reconnectTask = nil
        proactiveRecycleTask?.cancel()
        proactiveRecycleTask = nil
        reconnectConsecutiveFailures = 0
        streamStartedAt = nil
        // archivedSegments は consumeFinalizedTranscript で読んだ後にクリアする
        // （途中で stop → consume まで時間が空くケースあり）

        let closingStream = stream
        let closingPrepared = preparedSession
        stream = nil
        preparedSession = nil
        preparedAt = nil
        preparedLanguage = nil

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

        // liveSegments は installStream / observeStreamSegments の中で既に
        // 絶対時刻（音声ファイル基準）に変換済み。offset は加算不要。
        let segments = liveSegments.map { seg in
            TranscriptionResult.TranscriptionSegment(
                startTime: seg.start,
                endTime: seg.end,
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
        archivedSegments = []
        captureStartRecordingOffset = 0
        currentSessionOffset = 0

        return result
    }

    // MARK: - Helpers

    /// DeepgramStreamSession を組み立てる。Combine bind は `installStream` 内の
    /// `observeStreamSegments` で絶対時刻化しつつ行うため、ここでは session を返すだけ。
    private func makeSession(language: String) -> DeepgramStreamSession {
        let provider = DeepgramTokenProvider()
        var config = DeepgramStreamSession.Config()
        config.language = language
        return DeepgramStreamSession(tokenProvider: provider, config: config)
    }

    /// Live 接続失敗時の UI メッセージ。録音自体は継続するので「後処理で文字起こしされる」旨を明示する。
    /// 録音後の startTranscription() が Deepgram Batch → WhisperKit fallback で埋めてくれる。
    private func liveConnectFailureMessage(for error: Error) -> String {
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return "Couldn't connect to live captions (\(detail)). Recording will continue and the audio will be transcribed after you stop."
    }

    // MARK: - Stream install / recycle

    /// 新しく connect 済の session を active にし、監視・proactive recycle を仕込む。
    /// startLive の2経路（prepared 再利用 / 新規）・reconnect・recycle の4箇所から呼ばれる。
    ///
    /// reconnect / recycle で新 session に差し替わる際、旧 session の segment は
    /// その時点の currentSessionOffset を加えて絶対時刻化し archivedSegments に
    /// 退避する。新 session の segment は新しい currentSessionOffset 基準で絶対化される。
    private func installStream(_ session: DeepgramStreamSession) {
        // 1) 旧 session の segment を絶対時刻で archive。id を保持して UI flicker を防ぐ。
        if let oldSession = self.stream {
            let oldOffset = self.currentSessionOffset
            for seg in oldSession.finalizedSegments {
                archivedSegments.append(
                    DeepgramStreamSession.Segment(
                        id: seg.id,
                        text: seg.text,
                        start: seg.start + oldOffset,
                        end: seg.end + oldOffset,
                        language: seg.language
                    )
                )
            }
        }

        // 2) 新 session の offset を決定。capture 稼働中なら現在の録音ファイル位置、
        //    preconnect → startLive 直後はまだ capture.start 前なので 0（startLive で
        //    captureStartRecordingOffset を設定する時にまた上書きされる）。
        if self.capture != nil {
            self.currentSessionOffset = RecordingService.shared.currentDuration
        } else {
            self.currentSessionOffset = 0
        }

        // 3) 新 session を active 化
        self.stream = session
        self.streamStartedAt = Date()
        observeStreamState(session)
        observeStreamSegments(session)
        schedulePriactiveRecycle()
    }

    /// session の finalizedSegments / interimText を購読し、絶対時刻化した状態で
    /// `liveSegments` / `interimText` に反映する。
    private func observeStreamSegments(_ session: DeepgramStreamSession) {
        streamSegmentsSubscription?.cancel()
        streamSegmentsSubscription = session.$finalizedSegments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSegments in
                guard let self else { return }
                let offset = self.currentSessionOffset
                let absolute = newSegments.map { seg in
                    DeepgramStreamSession.Segment(
                        id: seg.id,                    // id 保持で UI 更新が diff で滑らかに
                        text: seg.text,
                        start: seg.start + offset,
                        end: seg.end + offset,
                        language: seg.language
                    )
                }
                self.liveSegments = self.archivedSegments + absolute
            }

        streamInterimSubscription?.cancel()
        streamInterimSubscription = session.$interimText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.interimText = text
            }
    }

    /// Deepgram のトークン期限（通常1h）や長時間セッションでの累積エラーを避けるため
    /// 一定時間ごとに session を差し替える。capture は停めず、新 session に繋ぎ直すだけ。
    private func schedulePriactiveRecycle() {
        proactiveRecycleTask?.cancel()
        proactiveRecycleTask = Task { @MainActor [weak self] in
            let delay = self?.proactiveRecycleInterval ?? 3000
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.capture != nil else { return }
            AppLogger.info("Deepgram: proactive session recycle (age \(Int(delay))s)", category: .transcription)
            self.triggerReconnectIfNeeded(reason: "proactive recycle")
        }
    }

    // MARK: - Reconnection

    /// Active な stream の connectionState を監視。内部 retry（最大3回）を使い切って
    /// .failed に落ちた場合に、外側からネット回復やタイマー契機で張り直すためのフック。
    private func observeStreamState(_ session: DeepgramStreamSession) {
        streamStateSubscription?.cancel()
        streamStateSubscription = session.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                if case .failed = state {
                    self.triggerReconnectIfNeeded(reason: "stream failed")
                }
            }
    }

    /// 録音継続中に stream が落ちた場合の再接続。
    /// - 条件: capture 生存中（= 録音中）、オンライン、Pro plan
    /// - 指数バックオフで最大 reconnectMaxAttempts 回試行し、ダメなら諦めて batch fallback に委ねる
    /// - 途中で stopLive されたらキャンセル
    private func triggerReconnectIfNeeded(reason: String) {
        guard capture != nil else { return }
        guard reconnectTask == nil else { return }
        guard AuthService.shared.isAuthenticated, PlanService.shared.isPaid else { return }
        // 既に上限に達している場合、NWPath 復帰 or 前景復帰まで待つ（そこで counter reset される）
        guard reconnectConsecutiveFailures < reconnectMaxAttempts else {
            AppLogger.info("Deepgram reconnect suppressed: max attempts reached, awaiting network/foreground event", category: .transcription)
            return
        }

        AppLogger.info("Deepgram: scheduling reconnect (\(reason), from attempt \(reconnectConsecutiveFailures + 1)/\(reconnectMaxAttempts))", category: .transcription)
        isReconnectingLive = true

        reconnectTask = Task { @MainActor [weak self] in
            defer { self?.reconnectTask = nil }
            guard let self else { return }

            // 同一 Task 内で最大 reconnectMaxAttempts 回まで再試行。
            // 再帰させない（reconnectTask != nil のガードで skip されるため）。
            while self.reconnectConsecutiveFailures < self.reconnectMaxAttempts {
                if Task.isCancelled { return }

                // 指数バックオフ: attempt=0 は即時、1→1s、2→3s
                let attempt = self.reconnectConsecutiveFailures
                if attempt > 0 {
                    let backoffSec = min(pow(2.0, Double(attempt)) - 1.0, 10.0)
                    try? await Task.sleep(nanoseconds: UInt64(backoffSec * 1_000_000_000))
                    if Task.isCancelled { return }
                }

                guard self.isOnline else {
                    AppLogger.info("Deepgram reconnect paused: offline (will retry on network recovery)", category: .transcription)
                    self.isReconnectingLive = false
                    return
                }
                guard self.capture != nil else {
                    self.isReconnectingLive = false
                    return
                }

                let language = TranscriptionService.shared.transcriptionLanguage.deepgramCode
                let newSession = self.makeSession(language: language)
                do {
                    try await newSession.connect()
                } catch {
                    AppLogger.warning("Deepgram reconnect attempt \(attempt + 1) failed: \(error.localizedDescription)", category: .transcription)
                    self.reconnectConsecutiveFailures += 1
                    if self.reconnectConsecutiveFailures >= self.reconnectMaxAttempts {
                        self.liveError = self.liveConnectFailureMessage(for: error)
                        self.isReconnectingLive = false
                        return
                    }
                    continue // 次の試行へ
                }

                // connect 中に stop されていたら破棄
                guard self.capture != nil else {
                    await newSession.finish()
                    self.isReconnectingLive = false
                    return
                }

                // 旧 stream は即切断（失敗済 or stale）
                let oldStream = self.stream
                self.installStream(newSession)
                self.reconnectConsecutiveFailures = 0
                self.liveError = nil
                self.isReconnectingLive = false
                Task { @MainActor in
                    await oldStream?.finish()
                }
                AppLogger.info("Deepgram reconnected (lang: \(language))", category: .transcription)
                return
            }
        }
    }
}
