//
//  RecordingService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import AVFoundation
import Combine
import ActivityKit
import UIKit
@preconcurrency import UserNotifications

/// Recording service
@MainActor
class RecordingService: NSObject, ObservableObject {
    static let shared = RecordingService()

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingStartTime: Date?
    @Published var pausedDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    /// startRecording で生成し、saveLecture で同じ UUID を Lecture.id に再利用する。
    /// WhisperLiveDecoder は録音中にこの ID を使って chunkCache に書き込み、
    /// post-stop の transcription path が cache 経由で結果を引き上げる。
    /// stopRecording / autoSave / cancel で nil に戻す。
    @Published private(set) var currentRecordingId: UUID?
    @Published var audioLevelHistory: [Float] = Array(repeating: 0, count: 30)
    @Published var showLowAudioWarning = false
    @Published var unexpectedlySavedRecording: SavedRecording?
    @Published var stoppedAtMaxDuration = false
    @Published var showMaxDurationWarning = false
    @Published var remainingSecondsBeforeAutoStop: Int = 0

    /// 録音中に audioLevel が low-audio 閾値を下回った累積秒数 (1Hz サンプリング、pause 時は加算しない)。
    /// startRecording で 0 にリセット、stopRecording 後も次の startRecording まで保持され、
    /// RecordView.saveLecture が Lecture.lowAudioSeconds に転写する。LectureDetailView の
    /// "Re-transcribe with audio boost" 自動サジェスト判定に使う。LiveCaptionView の
    /// MOVE CLOSER ピル閾値と同じ値 (0.08) を使うので、ピルが立っていた時間と概ね一致する。
    @Published var cumulativeLowAudioSeconds: Double = 0
    private let lowAudioLevelThreshold: Float = 0.08

    /// Current duration computed from wall clock (for use outside UI)
    var currentDuration: TimeInterval {
        guard let start = recordingStartTime else { return recordingDuration }
        if isPaused, let ps = pauseStartTime {
            return Date().timeIntervalSince(start) - pausedDuration - Date().timeIntervalSince(ps)
        }
        return Date().timeIntervalSince(start) - pausedDuration
    }

    struct SavedRecording: Equatable {
        let url: URL
        let duration: TimeInterval
        let title: String
        let startedAt: Date?
    }

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var meteringTimer: Timer?
    private var backgroundTaskTimer: Timer?
    private var lowAudioSeconds = 0
    private var recordingURL: URL?
    private var liveActivity: Activity<LecsyWidgetAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var currentLectureTitle: String = "New Recording"
    private var pauseStartTime: Date? // Pause start time

    // Support up to 180 minutes (10800 seconds = 3 hours) of recording.
    // Covers the longest common university lecture format.
    private let maxRecordingDuration: TimeInterval = 10800 // 180 minutes
    // Show a warning banner 5 minutes before auto-stop
    private let warningBeforeMax: TimeInterval = 300 // 5 minutes

    private var isAudioSessionPrepared = false
    private var recorderRestartCount = 0
    private let maxRecorderRestarts = 3

    /// Flag to distinguish intentional stop from unexpected termination
    private var isStoppingIntentionally = false

    // Persistence keys for crash recovery
    private let activeRecordingURLKey = "lecsy.activeRecordingURL"
    private let activeRecordingStartKey = "lecsy.activeRecordingStart"
    private let activeRecordingPausedKey = "lecsy.activeRecordingPaused"
    private let activeRecordingTitleKey = "lecsy.activeRecordingTitle"

    /// Combine subscriptions held for the lifetime of the singleton.
    /// Used today for the transcription-progress → Live Activity bridge.
    private var cancellables: Set<AnyCancellable> = []

    private override init() {
        super.init()
        setupNotifications()
        // Clean up zombie Live Activities from previous launches on startup
        cleanUpStaleLiveActivities()
        // Bridge transcription progress into the Live Activity so the user
        // can watch the post-stop WhisperKit batch from the lock screen /
        // Dynamic Island. The observer is a no-op until a Live Activity
        // exists and is in `.transcribing` phase.
        setupTranscriptionProgressObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Observe TranscriptionProgressService.chunkProgress and forward each
    /// update to the active Live Activity. Singleton transcription means
    /// the dictionary holds at most one entry at a time, so taking
    /// `values.first` is safe.
    private func setupTranscriptionProgressObserver() {
        TranscriptionProgressService.shared.$chunkProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] progressMap in
                guard let self = self else { return }
                guard self.liveActivity != nil else { return }
                guard let cp = progressMap.values.first else { return }
                // ETA は非表示 (chunk 単位の所要時間が振れて当てにならないため、
                // ユーザーから「remaining が伸びる」苦情が出た)。
                self.updateLiveActivityTranscribeProgress(
                    index: cp.index,
                    total: cp.total,
                    etaSeconds: nil
                )
            }
            .store(in: &cancellables)

        // Observe app active state during transcription. Background → GPU
        // command submission blocked → chunked decode pauses at next chunk
        // boundary. Live Activity needs to reflect this so user understands
        // why "Transcribing 5/8" looks frozen on the lock screen.
        TranscriptionService.shared.$isAppActive
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                guard let self = self, self.liveActivity != nil else { return }
                // Only relevant during transcription (chunkProgress exists).
                let progressMap = TranscriptionProgressService.shared.chunkProgress
                guard let cp = progressMap.values.first else { return }
                self.updateLiveActivityTranscribePauseState(
                    isPaused: !isActive,
                    index: cp.index,
                    total: cp.total
                )
            }
            .store(in: &cancellables)
    }

    /// Listen for app lifecycle and audio interruption notifications
    ///
    /// `NotificationCenter.addObserver(forName:queue:using:)` に渡すクロージャは
    /// `@Sendable` 相当で non-isolated。クラス本体は `@MainActor` なので
    /// クロージャ内部から self.isRecording 等の MainActor プロパティを参照すると
    /// Swift 6 strict で "cannot be referenced from a Sendable closure" になる。
    /// `queue: .main` 指定により main thread 配送されることが保証されているので、
    /// iOS 17+ の `MainActor.assumeIsolated` で isolation を表明してアクセスする。
    private func setupNotifications() {
        let nc = NotificationCenter.default

        // Grab a background task only when the app actually resigns active
        // while recording — holding it from startRecording() onward triggers
        // "Background Task ... created over 30 seconds ago" warnings whenever
        // the user records in the foreground (most of the time).
        // iOS keeps the recorder alive in the background via
        // UIBackgroundModes: audio + an active AVAudioRecorder — the task is
        // only a safety net for the transition window.
        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                self.setupBackgroundTask()
            }
        }
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.endBackgroundTask()
            }
        }

        // Restore audio session and metering when app returns to foreground
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                // Only re-activate (don't setCategory — it causes audio glitches)
                try? AVAudioSession.sharedInstance().setActive(true, options: [])

                // Wall-clock check: Timer is suspended in background, so the max-duration
                // check may have been skipped. Catch it immediately on foreground return.
                let elapsed = self.currentDuration
                if elapsed >= self.maxRecordingDuration {
                    AppLogger.info("Foreground return: recording exceeded max duration (\(Int(elapsed))s), auto-saving", category: .recording)
                    self.stoppedAtMaxDuration = true
                    self.autoSaveAndNotify()
                    return
                }
                // Update warning state if approaching limit
                let remaining = self.maxRecordingDuration - elapsed
                if remaining <= self.warningBeforeMax {
                    self.showMaxDurationWarning = true
                    self.remainingSecondsBeforeAutoStop = Int(remaining)
                }

                self.ensureRecorderIsRunning()
                self.restartMeteringTimerIfNeeded()
            }
        }

        // Handle audio session interruptions (phone calls, Siri, etc.)
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            // userInfo を MainActor 外で先に取り出す（Notification は non-Sendable）
            let rawType = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? UInt.max
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                guard let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

                if type == .began {
                    AppLogger.debug("Audio interruption began (phone call, Siri, etc.)", category: .recording)
                    // Persist state in case we get killed during interruption
                    self.persistRecordingState()
                } else if type == .ended {
                    AppLogger.debug("Audio interruption ended, attempting resume", category: .recording)
                    // If mic permission was revoked during the interruption, bail out safely.
                    if AVAudioSession.sharedInstance().recordPermission != .granted {
                        AppLogger.error("Mic permission revoked during interruption — auto-saving", category: .recording)
                        self.autoSaveAndNotify()
                        return
                    }
                    // Re-activate session after interruption (category is still correct)
                    self.restoreAudioSessionIfNeeded()
                    if !self.isPaused {
                        let remaining = max(1, self.maxRecordingDuration - self.recordingDuration)
                        self.audioRecorder?.record(forDuration: remaining)
                    }
                    // Hard-verify the recorder actually came back; restart if not.
                    self.ensureRecorderIsRunning()
                    self.persistRecordingState()
                }
            }
        }

        // Route changes (headphone unplug, Bluetooth disconnect): don't touch the
        // session, but verify the recorder is still producing data. If iOS paused
        // us, kick it back on.
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.ensureRecorderIsRunning()
                self.persistRecordingState()
            }
        }

        // Media services reset (rare but fatal): iOS has torn down the audio stack.
        // We must re-prepare the session and recreate the recorder pointing at the
        // *same* file so existing audio is preserved — AVAudioRecorder will append.
        nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                AppLogger.error("mediaServicesWereReset — persisting & attempting recovery", category: .recording)
                self.persistRecordingState()
                self.isAudioSessionPrepared = false
                self.restoreAudioSessionIfNeeded()
                // Last-resort: auto-save whatever we have so the user never loses the take.
                // A fresh recording can be started manually — partial data is safe on disk.
                self.autoSaveAndNotify()
            }
        }

        // Thermal state: on serious/critical, checkpoint aggressively so a forced
        // shutdown by the OS still leaves a recoverable file.
        nc.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                let state = ProcessInfo.processInfo.thermalState
                AppLogger.warning("Thermal state changed: \(state.rawValue)", category: .recording)
                if state == .serious || state == .critical {
                    // Drop metering overhead and checkpoint immediately.
                    self.meteringTimer?.invalidate()
                    self.meteringTimer = nil
                    self.audioLevelHistory = []
                    self.audioLevel = 0
                    self.persistRecordingState()
                }
            }
        }

        // Device locked with "Require Password Immediately" — file protection may
        // pull the rug out. Checkpoint so recoverOrphanedRecording() can save us.
        nc.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                AppLogger.warning("Protected data becoming unavailable — checkpointing", category: .recording)
                self.persistRecordingState()
            }
        }
        nc.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                self.ensureRecorderIsRunning()
            }
        }

        // Handle memory warnings — reduce non-essential work but keep recording
        nc.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                AppLogger.warning("Memory warning during recording — reducing overhead", category: .recording)
                // Stop metering to free CPU/memory, recording continues
                self.meteringTimer?.invalidate()
                self.meteringTimer = nil
                self.audioLevelHistory = []
                self.audioLevel = 0
            }
        }

        // Reduce resource usage when entering background to avoid iOS killing us
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                self.persistRecordingState()

                // Stop the 12Hz metering timer — it wastes CPU in background and can
                // cause iOS to deprioritize/kill our process. Recording continues fine
                // without it. We'll restart metering when we return to foreground.
                self.meteringTimer?.invalidate()
                self.meteringTimer = nil
                AppLogger.debug("Suspended metering timer for background efficiency", category: .recording)
            }
        }

        // Persist state when app might be terminated
        nc.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isRecording else { return }
                // AVAudioRecorder auto-flushes to disk, so the file is safe
                self.isStoppingIntentionally = true
                self.audioRecorder?.stop()
                self.persistRecordingState()
                AppLogger.warning("App terminating during recording — file preserved for recovery", category: .recording)
            }
        }
    }

    // MARK: - Recording State Persistence (crash recovery)

    /// Save current recording state to UserDefaults so we can recover after crash/kill
    private func persistRecordingState() {
        guard let url = recordingURL else { return }
        let defaults = UserDefaults.standard
        defaults.set(url.path, forKey: activeRecordingURLKey)
        defaults.set(recordingStartTime?.timeIntervalSince1970, forKey: activeRecordingStartKey)
        defaults.set(pausedDuration, forKey: activeRecordingPausedKey)
        defaults.set(currentLectureTitle, forKey: activeRecordingTitleKey)
    }

    /// Clear persisted recording state (called on successful stop)
    private func clearPersistedRecordingState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: activeRecordingURLKey)
        defaults.removeObject(forKey: activeRecordingStartKey)
        defaults.removeObject(forKey: activeRecordingPausedKey)
        defaults.removeObject(forKey: activeRecordingTitleKey)
    }

    /// Check for orphaned recording files from a previous crash and recover them
    func recoverOrphanedRecording() async -> (url: URL, duration: TimeInterval, title: String, startedAt: Date?)? {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: activeRecordingURLKey) else { return nil }

        let url = URL(fileURLWithPath: path)

        // Don't recover if we're currently recording (shouldn't happen)
        guard !isRecording else { return nil }

        // Validate file exists and is non-empty
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0 else {
            AppLogger.warning("Orphaned recording file missing or empty, skipping recovery", category: .recording)
            // Only clear after validation — don't lose the pointer prematurely
            clearPersistedRecordingState()
            return nil
        }

        // Calculate approximate duration from persisted start time
        var duration: TimeInterval = 0
        var startedAt: Date?
        if let startTimestamp = defaults.object(forKey: activeRecordingStartKey) as? TimeInterval {
            let pausedDur = defaults.double(forKey: activeRecordingPausedKey)
            let startDate = Date(timeIntervalSince1970: startTimestamp)
            startedAt = startDate
            duration = Date().timeIntervalSince(startDate) - pausedDur
        }

        // Get actual duration from file if possible
        let asset = AVURLAsset(url: url)
        if let track = try? await asset.loadTracks(withMediaType: .audio).first {
            let timeRange = try? await track.load(.timeRange)
            if let timeRange, CMTimeGetSeconds(timeRange.duration) > 0 {
                duration = CMTimeGetSeconds(timeRange.duration)
            }
        }

        // Ensure duration is non-negative (wall-clock drift can cause negative values)
        duration = max(0, duration)

        let title = defaults.string(forKey: activeRecordingTitleKey) ?? "Recovered Recording"
        AppLogger.info("Recovered orphaned recording: \(size) bytes, ~\(Int(duration))s", category: .recording)

        // 「音声は何があっても死守する」(memory: feedback_audio_must_survive.md):
        // crash で AVAudioRecorder.stop() が呼ばれずに終わった m4a は moov atom が
        // 末尾に書かれずに終わっていることがある。AVAudioPlayer はそれを開けないので、
        // Lecture に昇格させる前に AVAssetExportSession で再 mux 修復をかけ、
        // 再生可能な状態に揃えてから返す。失敗しても元ファイルはそのまま残すので
        // 後段の playback 側 (AudioPlayerService.loadAsync) でもう一度修復が走る。
        await ensureFinalizedM4A(at: url)

        // Clear persisted state only after successful recovery
        clearPersistedRecordingState()

        return (url: url, duration: duration, title: title, startedAt: startedAt)
    }

    /// `AudioFileRepairService` を使って m4a を再 mux し、原本を差し替える best-effort。
    /// 既に正しく moov atom が書かれているファイルでも export は通り抜けるので、
    /// 「壊れているか分からないが念のため」の cost として許容する。失敗時はログだけ
    /// 残して原本を維持し、playback 側でもう一度トライする。
    private func ensureFinalizedM4A(at url: URL) async {
        do {
            let repaired = try await AudioFileRepairService.shared.repair(at: url)
            _ = try AudioFileRepairService.shared.replace(original: url, with: repaired)
            AppLogger.info("Orphaned m4a finalized via re-mux: \(url.lastPathComponent)", category: .recording)
        } catch {
            AppLogger.warning(
                "Could not finalize orphaned m4a (\(url.lastPathComponent)): \(error.localizedDescription) — leaving raw file in place; playback will retry repair",
                category: .recording
            )
        }
    }

    // MARK: - Auto-save (unexpected termination fallback)

    /// Automatically save the current recording when the recorder dies unexpectedly.
    /// This creates a Lecture entry directly and notifies the UI via `unexpectedlySavedRecording`.
    private func autoSaveAndNotify() {
        guard isRecording, let url = recordingURL else { return }

        WhisperLiveDecoder.shared.stop()

        // Stop cleanly
        isStoppingIntentionally = true
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        // startRecording で begin した auto-lock 抑制を解除。
        // 切り忘れ "reached" 通知は cancel しない (届けたい)。
        ScreenAwakeLock.shared.end()

        isRecording = false
        isPaused = false

        let finalDuration = max(0, currentDuration)
        let capturedStart = recordingStartTime

        pauseStartTime = nil
        clearPersistedRecordingState()
        endLiveActivity()
        endBackgroundTask()

        // Validate file
        guard FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64, size > 0 else {
            AppLogger.error("Auto-save failed: file missing or empty", category: .recording)
            return
        }

        let title = currentLectureTitle
        recordingURL = nil
        recordingStartTime = nil
        pausedDuration = 0
        audioLevel = 0
        audioLevelHistory = Array(repeating: 0, count: 30)
        showMaxDurationWarning = false
        remainingSecondsBeforeAutoStop = 0

        // AVAudioRecorder.stop() は同期 return するが m4a の moov atom 書き込みは
        // audio thread の internal queue で非同期 → ここで即 setActive(false) すると
        // finalize が中断されて moov 無しの壊れた m4a が残る (VPN ON 環境で再現報告)。
        // delegate (audioRecorderDidFinishRecording) で finalize 完了を待ってから
        // 解除する。fail-safe として 1.5s timeout も仕込む。
        scheduleAudioSessionDeactivation()

        AppLogger.info("Auto-saved recording after unexpected stop: \(size) bytes, \(Int(finalDuration))s", category: .recording)

        // Notify UI so it can present the save sheet
        unexpectedlySavedRecording = SavedRecording(url: url, duration: finalDuration, title: title, startedAt: capturedStart)
    }

    // MARK: - Recorder Health

    /// Restart metering timer (after returning from background)
    private func restartMeteringTimerIfNeeded() {
        guard isRecording, meteringTimer == nil else { return }
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.audioRecorder?.updateMeters()
                let db = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let normalized = max(0, min(1, (db + 60) / 55))
                self.audioLevel = normalized
                if self.audioLevelHistory.count >= 60 {
                    self.audioLevelHistory.removeFirst(self.audioLevelHistory.count - 30)
                }
                self.audioLevelHistory.append(normalized)
            }
        }
        if let meteringTimer = meteringTimer {
            RunLoop.current.add(meteringTimer, forMode: .common)
        }
    }

    /// Ensure the recorder is actively recording; restart if needed
    private func ensureRecorderIsRunning() {
        guard isRecording, !isPaused else { return }
        guard let recorder = audioRecorder else { return }

        if !recorder.isRecording {
            if recorderRestartCount < maxRecorderRestarts {
                AppLogger.warning("Recorder stopped unexpectedly, attempting restart (\(recorderRestartCount + 1)/\(maxRecorderRestarts))", category: .recording)
                let remaining = max(1, maxRecordingDuration - recordingDuration)
                recorder.record(forDuration: remaining)
                recorderRestartCount += 1
            }
        }
    }

    /// Re-activate audio session after background / interruption.
    ///
    /// Key design decisions for background resilience:
    /// - `.mixWithOthers` is NOT used: we need exclusive audio so iOS keeps us alive
    /// - `.setActive(true, options: [])` without `.notifyOthersOnDeactivation`: we
    ///   don't want to deactivate other sessions — we just reclaim ours
    /// - Category is re-set every time: after a phone call, iOS may have changed it
    private func restoreAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Only set category if it's not already correct.
            // Calling setCategory during active recording causes audio glitches.
            // Always use `.measurement`: this is a lecture app — 90% of sessions
            // are far-field (phone on desk, speaker 3〜30m away). .measurement
            // disables iOS voice-processing (AGC / noise suppression / echo-
            // cancel) which otherwise treats quiet far-field speech as noise
            // and removes it. Near-field capture still works fine with raw audio.
            if session.category != .playAndRecord || session.mode != .measurement {
                try session.setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.defaultToSpeaker, .allowBluetooth]
                )
            }
            try session.setActive(true, options: [])
        } catch {
            AppLogger.warning("Failed to re-activate audio session: \(error)", category: .recording)
        }
    }

    /// saveLecture が currentRecordingId を読み出して Lecture.id にする際に呼ぶ。
    /// 同じ ID で WhisperLiveDecoder の chunkCache が育っているので、Lecture.id と
    /// 一致させることで post-stop の transcription path が cache を引き上げられる。
    /// 取り出した時点で nil にして次の録音に備える。
    func consumeRecordingId() -> UUID? {
        let id = currentRecordingId
        currentRecordingId = nil
        return id
    }

    /// Pre-configure audio session so recording starts instantly
    func prepareAudioSession() {
        guard !isAudioSessionPrepared else { return }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // See restoreAudioSessionIfNeeded() for why `.measurement` is the
            // only mode used by this lecture app.
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true, options: [])

            if UIDevice.current.userInterfaceIdiom == .pad {
                if let availableInputs = audioSession.availableInputs,
                   let builtInMic = availableInputs.first(where: { $0.portType == .builtInMic }) {
                    try? audioSession.setPreferredInput(builtInMic)
                }
            }

            isAudioSessionPrepared = true
            AppLogger.debug("Audio session pre-configured", category: .recording)
        } catch {
            AppLogger.warning("Failed to pre-configure audio session: \(error)", category: .recording)
        }
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Start recording
    func startRecording(lectureTitle: String = "New Recording") async throws {
        AppLogger.debug("RecordingService.startRecording() called", category: .recording)
        
        guard !isRecording else {
            AppLogger.debug("Already recording", category: .recording)
            return
        }
        
        // Check microphone permission
        let hasPermission = AVAudioSession.sharedInstance().recordPermission
        AppLogger.debug("Microphone permission status: \(hasPermission.rawValue)", category: .recording)
        guard hasPermission == .granted else {
            AppLogger.debug("No microphone permission", category: .recording)
            throw RecordingError.permissionDenied
        }
        
        // Check disk space (approximately 90-180MB needed for 180 minutes at 64kbps)
        let requiredSpace: Int64 = 200 * 1024 * 1024 // 200MB
        if let availableSpace = getAvailableDiskSpace(), availableSpace < requiredSpace {
            AppLogger.debug("Insufficient disk space: Available \(availableSpace / 1024 / 1024)MB, Required \(requiredSpace / 1024 / 1024)MB", category: .recording)
            throw RecordingError.insufficientStorage
        }
        
        // Ensure audio session is ready (should already be prepared)
        if !isAudioSessionPrepared {
            prepareAudioSession()
        }

        // Always re-activate audio session before recording
        // (previous stop may have deactivated it, or another app may hold it)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true, options: [])
        } catch {
            AppLogger.error("Audio session activation error: \(error)", category: .recording)
            throw RecordingError.recordingFailed
        }
        
        // Background task is started lazily when the app resigns active —
        // see setupNotifications(). This avoids the "Background Task created
        // over 30 seconds ago" foreground warning for every recording.

        // Recording file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            AppLogger.error("Failed to create recording file URL", category: .recording)
            throw RecordingError.fileCreationFailed
        }
        
        AppLogger.debug("Recording file URL: \(url)", category: .recording)
        
        // Recording settings (optimized for long recording: balance quality and file size)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue, // Changed to medium for long recording
            AVEncoderBitRateKey: 64000 // 64kbps (~50MB/100min, ~90MB/180min)
        ]
        
        // Start recording
        AppLogger.debug("Creating AVAudioRecorder", category: .recording)
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            // Use record(forDuration:) as a hard backstop — AVAudioRecorder
            // enforces this in the audio system, even when the app is suspended
            // in background. The Timer-based check is a soft fallback only.
            let recordingStarted = audioRecorder?.record(forDuration: maxRecordingDuration) ?? false
            AppLogger.debug("Recording started: \(recordingStarted)", category: .recording)
            
            if !recordingStarted {
                AppLogger.error("Failed to start recording", category: .recording)
                throw RecordingError.recordingFailed
            }

            // Protect audio file: completeUntilFirstUserAuthentication is safe for
            // background recording (does NOT lock when device locks). Also exclude
            // from iCloud/iTunes backup so audio stays on-device only.
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            var protectedURL = url
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? protectedURL.setResourceValues(rv)
        } catch {
            AppLogger.error("AVAudioRecorder creation/start error: \(error)", category: .recording)
            throw RecordingError.recordingFailed
        }
        
        isRecording = true
        isPaused = false
        isStoppingIntentionally = false
        recordingStartTime = Date()
        recordingDuration = 0
        pausedDuration = 0
        pauseStartTime = nil
        currentLectureTitle = lectureTitle
        lowAudioSeconds = 0
        showLowAudioWarning = false
        cumulativeLowAudioSeconds = 0
        currentRecordingId = UUID()

        persistRecordingState()
        startLiveActivity()
        recorderRestartCount = 0

        // 録音中は AVAudioRecorder 単独で走らせる。AVAudioEngine.installTap
        // との並行マイク占有 (旧: WhisperLiveDecoder の live decode) は Apple
        // 推奨外で、VPN / thermal serious / 高負荷下で AAC encoder fault →
        // m4a finalize 失敗 (moov atom 未書込) の再現報告がある (2026-04-29、
        // Free / VPN 環境で複数ユーザー)。「音声死守」を構造的に守るため、
        // 録音中は Apple サポート構成 (AVAudioRecorder 単独) に統一する。
        // 文字起こしは録音停止後の batch chunked decode (startTranscription)
        // に集約。memory: feedback_audio_must_survive.md。

        // Duration timer (1Hz)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self, let startTime = self.recordingStartTime else {
                t.invalidate()
                return
            }
            if !self.isPaused {
                self.recordingDuration = Date().timeIntervalSince(startTime) - self.pausedDuration
                // 1Hz で audioLevel をサンプリングして累積 low-audio 秒数を伸ばす。pause 中は
                // metering timer も止まっているので audioLevel は古い値のまま → ここで加算しない。
                if self.audioLevel < self.lowAudioLevelThreshold {
                    self.cumulativeLowAudioSeconds += 1
                }
            }
            // Persist state every 10 seconds
            if Int(self.recordingDuration) % 10 == 0 {
                self.persistRecordingState()
            }
            // Show warning banner when approaching the limit
            let remaining = self.maxRecordingDuration - self.recordingDuration
            if remaining <= self.warningBeforeMax && remaining > 0 {
                if !self.showMaxDurationWarning {
                    AppLogger.info("Recording approaching max duration — \(Int(remaining))s remaining", category: .recording)
                }
                self.showMaxDurationWarning = true
                self.remainingSecondsBeforeAutoStop = Int(remaining)
            }
            // Soft check (belt): Timer may not fire reliably in background,
            // but record(forDuration:) is the hard backstop.
            if self.recordingDuration >= self.maxRecordingDuration {
                AppLogger.info("Max recording duration reached (\(Int(self.maxRecordingDuration))s), auto-saving", category: .recording)
                self.stoppedAtMaxDuration = true
                self.autoSaveAndNotify()
                return
            }
            // Health check every 10 seconds
            if Int(self.recordingDuration) % 10 == 0 {
                self.ensureRecorderIsRunning()
            }
            // Disk space check every 30 seconds
            if Int(self.recordingDuration) % 30 == 0 {
                let minSpace: Int64 = 10 * 1024 * 1024
                if let available = self.getAvailableDiskSpace(), available < minSpace {
                    _ = self.stopRecording()
                }
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }

        // Metering timer (8Hz — smooth waveform animation)
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.audioRecorder?.updateMeters()
                let db = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                // 拡張正規化レンジ: -75dB ~ 0dB → 0...1
                // 旧 (-60...-5dB) は遠距離 lecture (-46dB 等) で bar が
                // ほぼ static = 「マイク死んでるように見える」苦情。
                // 75dB のダイナミックレンジで -46dB → 0.39 まで上げる。
                // 上限を 0dB に変えても clip 警告 (>0.85) は残るので OK。
                let normalized = max(0, min(1, (db + 75) / 75))
                self.audioLevel = normalized
                if self.audioLevelHistory.count >= 60 {
                    self.audioLevelHistory.removeFirst(self.audioLevelHistory.count - 30)
                }
                self.audioLevelHistory.append(normalized)
            }
        }
        if let meteringTimer = meteringTimer {
            RunLoop.current.add(meteringTimer, forMode: .common)
        }

        setupBackgroundTaskRenewal()
        scheduleMaxDurationNotifications()
        // 録音中の screen auto-lock を無効化 (画面ロックで Live Activity だけに
        // なるとユーザーの監視性が落ちる)。stopRecording / autoSaveAndNotify で
        // 必ず end する。
        ScreenAwakeLock.shared.begin()
        AppLogger.debug("Recording started", category: .recording)
    }

    // MARK: - 切り忘れ通知 (local notifications)
    //
    // 現実の使用シナリオ: 学生が録音開始 → ポケットに iPhone → 授業中で画面見ない
    // → 3 時間経過 → 180min cap で silent auto-stop → ユーザー知らず、次の授業も
    // 録れてると思い込む。foreground 5 分前バナーは見えない。
    // 対策: max 直前/到達時に local notification を投げて、画面ロック中・別アプリ中
    // でもユーザーに気付かせる。stopRecording で全 cancel するので残らない。
    private static let maxNotificationIds = [
        "lecsy.maxDuration.warning30min",
        "lecsy.maxDuration.warning5min",
        "lecsy.maxDuration.reached",
    ]

    private func scheduleMaxDurationNotifications() {
        let center = UNUserNotificationCenter.current()
        // 静かに authorization request (初録音時)。denied でも害はない (UNAuthorization
        // status を別途見る方法もあるが、毎回 request しても denied は no-op)。
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor [weak self] in
                self?.installMaxDurationNotifications()
            }
        }
    }

    private func installMaxDurationNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: Self.maxNotificationIds
        )

        let warning30: TimeInterval = max(60, maxRecordingDuration - 1800) // 30 min before
        let warning5:  TimeInterval = max(60, maxRecordingDuration - 300)  // 5 min before
        let reached:   TimeInterval = maxRecordingDuration

        let entries: [(id: String, after: TimeInterval, title: String, body: String)] = [
            (Self.maxNotificationIds[0], warning30,
             "Recording — 30 min left",
             "Lecsy will auto-stop at 3 hours. Tap to stop now if you're done."),
            (Self.maxNotificationIds[1], warning5,
             "Recording — 5 min left",
             "Lecsy will auto-stop in 5 minutes. Tap to keep your audio safe."),
            (Self.maxNotificationIds[2], reached,
             "Recording stopped automatically",
             "Reached the 3-hour limit. Your audio is saved — start a new recording to continue."),
        ]

        for entry in entries {
            let content = UNMutableNotificationContent()
            content.title = entry.title
            content.body = entry.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: entry.after, repeats: false)
            let request = UNNotificationRequest(identifier: entry.id, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    private func cancelMaxDurationNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Self.maxNotificationIds
        )
    }

    /// Pause recording
    func pauseRecording() {
        guard isRecording, !isPaused else { return }

        AppLogger.debug("Pausing recording", category: .recording)
        audioRecorder?.pause()
        isPaused = true
        pauseStartTime = Date()
        WhisperLiveDecoder.shared.pause()

        // Persist state immediately (safety net if app is killed while paused)
        persistRecordingState()
        // Update Live Activity (reflect pause state)
        updateLiveActivity()
    }

    /// Resume recording
    func resumeRecording() {
        guard isRecording, isPaused else { return }

        AppLogger.debug("Resuming recording", category: .recording)

        // Accumulate pause time
        if let pauseStart = pauseStartTime {
            let pauseDuration = Date().timeIntervalSince(pauseStart)
            pausedDuration += pauseDuration
            pauseStartTime = nil
        }

        // Re-start with remaining duration so the hard backstop stays active
        let remaining = max(1, maxRecordingDuration - recordingDuration)
        audioRecorder?.record(forDuration: remaining)
        isPaused = false
        WhisperLiveDecoder.shared.resume()

        // Persist state immediately
        persistRecordingState()
        // Update Live Activity (reflect resume state)
        updateLiveActivity()
    }
    
    /// Stop recording
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        // Eagerly preload WhisperKit so it's hot by the time the AAC file finalizes.
        Task { await TranscriptionService.shared.warmupModel() }

        // Free 用 live decoder を停止。tap を外して engine を止め、queue は
        // 背景で drain。currentRecordingId は saveLecture が消費するまで残す。
        WhisperLiveDecoder.shared.stop()
        // 手動 stop なので予約してた切り忘れ通知は全 cancel。
        // autoSaveAndNotify (180min 到達) 経路は cancel しない —
        // "reached" 通知をユーザーに届けたいので。
        cancelMaxDurationNotifications()
        // startRecording で begin した auto-lock 抑制を解除。
        ScreenAwakeLock.shared.end()

        isStoppingIntentionally = true
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil

        isRecording = false
        isPaused = false
        pauseStartTime = nil
        audioLevel = 0
        audioLevelHistory = Array(repeating: 0, count: 30)
        showMaxDurationWarning = false
        remainingSecondsBeforeAutoStop = 0

        // Clear crash-recovery state (recording completed normally)
        clearPersistedRecordingState()

        // Live Activity transition:
        //   - Pro: Deepgram captioning is already done in real time, so the
        //     activity ends right here (legacy behavior).
        //   - Free: WhisperKit batch is about to start, so we keep the
        //     activity alive and flip it into `.transcribing`. The
        //     TranscriptionProgressService observer in init() will drive
        //     chunk index / ETA from there, and RecordView calls
        //     `finishLiveActivityWithDone()` when the transcript settles.
        if PlanService.shared.isPaid {
            endLiveActivity()
        } else {
            transitionLiveActivityToTranscribing()
        }

        // End background task
        endBackgroundTask()

        let url = recordingURL
        recordingURL = nil
        recordingStartTime = nil
        pausedDuration = 0
        audioRecorder = nil // Release old recorder so stale delegates are ignored

        // Deactivate audio session — but wait for the m4a moov atom to be written.
        // AVAudioRecorder.stop() returns synchronously yet finalization happens on
        // the audio thread's internal queue. Calling setActive(false) immediately
        // can interrupt that finalization and leave a moov-less, unplayable m4a
        // (reproduced by users on VPN where iOS network/audio threads are loaded).
        // The delegate (audioRecorderDidFinishRecording) deactivates as soon as
        // finalization completes; this is the fail-safe in case the delegate
        // never fires.
        scheduleAudioSessionDeactivation()

        // Validate recording file — but be lenient: return the URL even if
        // we can't verify, since partial data is better than losing everything
        if let url = url {
            if !FileManager.default.fileExists(atPath: url.path) {
                AppLogger.error("Recording file does not exist after stop: \(url.path)", category: .recording)
                return nil
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                AppLogger.debug("Recording file size: \(size) bytes", category: .recording)
                if size == 0 {
                    AppLogger.error("Recording file is empty (0 bytes)", category: .recording)
                    return nil
                }
            }
        }

        return url
    }
    
    // MARK: - Disk Space Management
    
    /// Get available disk space (in bytes)
    private func getAvailableDiskSpace() -> Int64? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                return freeSpace
            }
        } catch {
            AppLogger.error("Disk space retrieval error: \(error)", category: .recording)
        }
        
        return nil
    }
    
    // MARK: - Background Task Management

    /// Background task renewal.
    ///
    /// IMPORTANT: `beginBackgroundTask` gives ~30 seconds of grace time.
    /// You CANNOT extend it by creating new tasks in a loop — iOS ignores this.
    /// The REAL background protection comes from `UIBackgroundModes: audio` +
    /// an active AVAudioRecorder. The background task is only a safety net
    /// for the brief window between entering background and the audio system
    /// confirming our recording is still active.
    private func setupBackgroundTaskRenewal() {
        // No timer-based renewal — it doesn't work and wastes resources.
        // The single background task from setupBackgroundTask() is sufficient.
        // iOS audio background mode keeps us alive as long as we're recording.
    }
    
    // MARK: - Live Activities
    
    /// Start Live Activity
    private func startLiveActivity() {
        // Check if ActivityKit is available
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.warning("Live Activities are not enabled", category: .recording)
            return
        }

        // Clean up any stale activities from previous sessions before starting a new one
        cleanUpStaleLiveActivities()

        let attributes = LecsyWidgetAttributes(lectureTitle: currentLectureTitle)
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: 0,
            isRecording: true,
            recordingStartDate: recordingStartTime,
            isPaused: false
        )

        do {
            liveActivity = try Activity<LecsyWidgetAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            AppLogger.debug("Live Activity started (id: \(liveActivity?.id ?? "nil"))", category: .recording)
        } catch {
            AppLogger.error("Failed to start Live Activity: \(error)", category: .recording)
        }
    }

    /// End all stale Live Activities left over from previous sessions (crash, force-quit, etc.)
    private func cleanUpStaleLiveActivities() {
        let staleActivities = Activity<LecsyWidgetAttributes>.activities
        for activity in staleActivities {
            // Don't end our current activity if we somehow still have a reference
            if activity.id == liveActivity?.id { continue }
            let finalState = LecsyWidgetAttributes.ContentState(
                recordingDuration: 0,
                isRecording: false,
                recordingStartDate: nil,
                isPaused: false
            )
            Task {
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
            AppLogger.debug("Cleaned up stale Live Activity: \(activity.id)", category: .recording)
        }
    }
    
    /// Update Live Activity
    private func updateLiveActivity() {
        guard let liveActivity = liveActivity else { return }

        // When recording (not paused), pass the effective start date so the
        // system-driven Text(timerInterval:) can tick every second on its own.
        let effectiveStartDate: Date? = if isRecording && !isPaused, let start = recordingStartTime {
            start.addingTimeInterval(pausedDuration)
        } else {
            nil
        }

        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: currentDuration,
            isRecording: isRecording,
            recordingStartDate: effectiveStartDate,
            isPaused: isPaused
        )

        Task { @MainActor in
            await liveActivity.update(
                using: contentState,
                alertConfiguration: nil
            )
        }
    }
    
    /// End Live Activity
    private func endLiveActivity() {
        guard let liveActivity = liveActivity else { return }

        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: currentDuration,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: false
        )

        Task {
            // Show final state briefly before dismissing so the user sees it ended
            await liveActivity.end(
                using: contentState,
                dismissalPolicy: .after(Date().addingTimeInterval(4))
            )
        }

        self.liveActivity = nil
    }

    /// Switch the Live Activity into the `.transcribing` phase. Called from
    /// stopRecording on the Free path so the activity stays alive while
    /// the post-stop WhisperKit batch grinds through chunks.
    /// chunk index/total/eta are filled in later by the
    /// TranscriptionProgressService observer.
    private func transitionLiveActivityToTranscribing() {
        guard let liveActivity = liveActivity else { return }
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: currentDuration,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: false,
            phase: .transcribing,
            transcribeChunkIndex: nil,
            transcribeChunkTotal: nil,
            transcribeETASeconds: nil
        )
        Task { @MainActor in
            await liveActivity.update(using: contentState, alertConfiguration: nil)
        }
    }

    /// Update the in-flight transcribing Live Activity with the current
    /// chunk index / total / ETA. Driven by the
    /// TranscriptionProgressService observer set up in init.
    private func updateLiveActivityTranscribeProgress(index: Int, total: Int, etaSeconds: Int?) {
        guard let liveActivity = liveActivity else { return }
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: currentDuration,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: false,
            phase: .transcribing,
            transcribeChunkIndex: index,
            transcribeChunkTotal: total,
            transcribeETASeconds: etaSeconds
        )
        Task { @MainActor in
            await liveActivity.update(using: contentState, alertConfiguration: nil)
        }
    }

    /// Background 中で chunked decode が一時停止した時に LA を `.paused` 相当に
    /// 切替える。`isPaused = true` を立てることで widget 側の表示分岐を可能
    /// にする (widget は isPaused を見て "Paused — open Lecsy" を出す)。
    /// chunk index/total は最終既知値を保持。再アクティブ時は通常 progress
    /// 更新で上書きされる。
    private func updateLiveActivityTranscribePauseState(isPaused: Bool, index: Int, total: Int) {
        guard let liveActivity = liveActivity else { return }
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: currentDuration,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: isPaused,
            phase: .transcribing,
            transcribeChunkIndex: index,
            transcribeChunkTotal: total,
            transcribeETASeconds: nil
        )
        Task { @MainActor in
            await liveActivity.update(using: contentState, alertConfiguration: nil)
        }
    }

    /// Public entry point used by RecordView when transcription resolves
    /// (success or failure). Flips the activity to `.done` for ~3 seconds
    /// so the user sees a checkmark, then dismisses it. No-op if there is
    /// no active activity (Pro path which already ended at stopRecording).
    func finishLiveActivityWithDone() {
        guard let liveActivity = liveActivity else { return }
        let doneState = LecsyWidgetAttributes.ContentState(
            recordingDuration: currentDuration,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: false,
            phase: .done
        )
        Task { @MainActor in
            await liveActivity.update(using: doneState, alertConfiguration: nil)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await liveActivity.end(using: doneState, dismissalPolicy: .immediate)
        }
        self.liveActivity = nil
    }
    
    // MARK: - Background Task

    /// Start background task.
    /// The expiry handler is our LAST CHANCE before iOS suspends us.
    /// Persist state so we can recover if we get killed.
    private func setupBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            // Last chance — persist everything
            if self.isRecording {
                self.persistRecordingState()
                AppLogger.warning("Background task expiring — state persisted for recovery", category: .recording)
            }
            self.endBackgroundTask()
        }
    }
    
    /// End background task
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    /// AVAudioRecorder.stop() の m4a finalize 完了を待ってから AVAudioSession を
    /// deactivate するための fail-safe timeout。delegate
    /// (audioRecorderDidFinishRecording) が呼ばれれば即解除されるが、呼ばれない
    /// 異常系のために 1.5s 後に必ず deactivate する。`deactivateAudioSessionIfNeeded()`
    /// は冪等なので、delegate と timeout の両方が走っても二重解除にならない。
    private func scheduleAudioSessionDeactivation() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.deactivateAudioSessionIfNeeded()
        }
    }

    /// 冪等に AVAudioSession を deactivate する。`isAudioSessionPrepared` を
    /// 「まだ解除していない」フラグに兼用しているので、2 回目以降の呼び出しは no-op。
    private func deactivateAudioSessionIfNeeded() {
        guard isAudioSessionPrepared else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isAudioSessionPrepared = false
    }

    /// Recording error
    enum RecordingError: LocalizedError {
        case permissionDenied
        case fileCreationFailed
        case recordingFailed
        case insufficientStorage
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone access permission is required"
            case .fileCreationFailed:
                return "Failed to create recording file"
            case .recordingFailed:
                return "Recording failed"
            case .insufficientStorage:
                return "Insufficient storage space. At least 200MB of free space is required."
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            // Ignore callbacks from old recorders or intentional stops
            if isStoppingIntentionally {
                isStoppingIntentionally = false
                // m4a の moov atom 書き込みが完了したシグナル → 安全に session を解除できる。
                // stopRecording / autoSaveAndNotify は scheduleAudioSessionDeactivation()
                // の fail-safe timeout だけ仕込んで、実際の解除をここに任せている。
                deactivateAudioSessionIfNeeded()
                return
            }
            guard recorder === audioRecorder else { return }
            guard isRecording else { return }

            if flag {
                // Recorder stopped on its own with success — this means
                // record(forDuration:) hit the time limit. Auto-save.
                AppLogger.info("Recorder finished (forDuration limit reached in \(flag ? "background" : "foreground")), auto-saving", category: .recording)
                stoppedAtMaxDuration = true
                autoSaveAndNotify()
            } else {
                // Recording failed unexpectedly — auto-save whatever we have.
                // Partial data is better than losing the entire session.
                AppLogger.warning("Recorder finished unexpectedly (success=false), auto-saving", category: .recording)
                persistRecordingState()
                autoSaveAndNotify()
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            AppLogger.error("Recording encode error: \(error?.localizedDescription ?? "Unknown error")", category: .recording)
            // Checkpoint first so whatever is on disk is safe, then auto-save the
            // take as a Lecture. Better to give the user a slightly shorter file
            // than to keep a dead recorder running and lose the whole session.
            persistRecordingState()
            autoSaveAndNotify()
        }
    }

    nonisolated func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        Task { @MainActor in
            AppLogger.debug("Recording interrupted (e.g., phone call)", category: .recording)
            persistRecordingState()
        }
    }

    nonisolated func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        Task { @MainActor in
            AppLogger.debug("Recording interruption ended", category: .recording)
            restoreAudioSessionIfNeeded()
            if isRecording && !isPaused {
                let remaining = max(1, maxRecordingDuration - recordingDuration)
                audioRecorder?.record(forDuration: remaining)
            }
            ensureRecorderIsRunning()
            persistRecordingState()
        }
    }
}
