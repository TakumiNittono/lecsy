//
//  TranscriptionService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import WhisperKit
import AVFoundation
import CoreMedia
import Combine
import CoreML
import Network
import UIKit

/// Transcription service
@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published var state: TranscriptionState = .idle
    @Published var progress: Double = 0
    @Published var downloadStatusText: String = ""
    @Published var downloadElapsedSeconds: Int = 0
    @Published var transcriptionLanguage: TranscriptionLanguage = .english
    @Published var isModelLoaded: Bool = false
    @Published var isMultilingualKitInstalled: Bool = false
    @Published var isDownloadingMultilingualKit: Bool = false
    @Published var multilingualKitDownloadFailed: Bool = false

    private var whisperKit: WhisperKit?
    private var whisperKit2: WhisperKit? // Second instance for parallel chunk processing on >=6GB RAM devices
    private var warmupTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private var modelDownloadTask: Task<Void, Error>?
    private var networkMonitor: NWPathMonitor?

    // MARK: - App-state pause (GPU background execution workaround)
    //
    // iOS blocks Metal/GPU command submission from background processes
    // (`kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`).
    // WhisperKit's CoreML decoder runs on the GPU, so any chunk that tries
    // to execute while the app is backgrounded dies with that error and
    // loses ~30s of audio. This happens whenever the system briefly pushes
    // Lecsy offscreen — e.g. the Google sign-in ASWebAuthenticationSession
    // taking focus during an active transcription.
    //
    // The `BackgroundKeepAlive` silent-audio trick keeps the *process*
    // alive (audio background mode) but cannot grant GPU execution rights
    // — that's a separate entitlement Apple doesn't expose to third-party
    // apps. So we instead pause the chunk loop at safe boundaries when the
    // app resigns active, and resume it when the app becomes active again.
    private var isAppActive: Bool = true
    private var foregroundContinuation: CheckedContinuation<Void, Never>?
    private var backgroundObserverToken: NSObjectProtocol?
    private var foregroundObserverToken: NSObjectProtocol?

    // Timeout settings
    private let modelLoadTimeout: TimeInterval = 600 // 10 minutes (460MB needs time on slower connections)
    private let perChunkTimeout: TimeInterval = 90 // 90s per chunk (aggressive — kills stuck decoding)

    // Chunking settings
    private let firstChunkDuration: TimeInterval = 15 // First chunk is short → first text appears fast
    private let chunkDuration: TimeInterval = 45 // 45s per chunk — first text appears ~3x faster than 2min
    private let chunkOverlap: TimeInterval = 2 // 2 seconds overlap to avoid cutting words
    private let shortAudioThreshold: TimeInterval = 60 // Under 1 min → process whole file

    // Model selection (multilingual — supports English, Japanese, etc.):
    private static let bundledModel = "small"
    private static let downloadModel = "small"
    private static let upgradeModel = "small"

    /// The model that will actually be used
    private var preferredModel: String {
        if isModelBundled { return Self.bundledModel }
        if UserDefaults.standard.string(forKey: "lecsy.activeModelName") == Self.upgradeModel,
           isModelCached(Self.upgradeModel) {
            return Self.upgradeModel
        }
        return Self.downloadModel
    }

    /// The model name currently loaded / to be used
    var activeModelName: String { preferredModel }

    /// Whether a better model is available to upgrade to
    var canUpgradeModel: Bool {
        guard !isModelBundled else { return false }
        if UserDefaults.standard.bool(forKey: "lecsy.didUpgradeModel") { return false }
        let current = UserDefaults.standard.string(forKey: "lecsy.activeModelName") ?? Self.downloadModel
        return current == Self.downloadModel
    }

    /// Whether the AI model is bundled with the app (no download needed)
    var isModelBundled: Bool { bundledModelPath != nil }

    /// Path to bundled model in app bundle (nil if not bundled)
    /// Finds AudioEncoder.mlmodelc in the bundle — its parent dir is the model folder.
    private var bundledModelPath: String? {
        if let encoderURL = Bundle.main.url(forResource: "AudioEncoder", withExtension: "mlmodelc") {
            return encoderURL.deletingLastPathComponent().path
        }
        return nil
    }

    private init() {
        // Restore saved language preference
        if let saved = UserDefaults.standard.string(forKey: "lecsy.transcriptionLanguage"),
           let lang = TranscriptionLanguage(rawValue: saved) {
            transcriptionLanguage = lang
        }
        // Migrate from old English-only models (.en) to multilingual models
        migrateFromEnglishOnlyModels()
        // Check if multilingual kit (small model) is available
        updateMultilingualKitStatus()
        // Reset to English if saved language requires kit that's not installed
        if transcriptionLanguage.requiresMultilingualKit && !isMultilingualKitInstalled {
            transcriptionLanguage = .english
            UserDefaults.standard.set(TranscriptionLanguage.english.rawValue, forKey: "lecsy.transcriptionLanguage")
        }
        AppLogger.debug("TranscriptionService initialized (multilingual, lang: \(transcriptionLanguage.rawValue), kit: \(isMultilingualKitInstalled))", category: .transcription)
        // On first launch after bundled update: clean up old downloaded cache
        if isModelBundled {
            cleanUpOldCacheIfNeeded()
        }
        // WhisperKit preload policy:
        //  - Cached Free plan → preload immediately (they rely on it)
        //  - Cached Pro plan → defer 15s so Deepgram warm-up / recording startup
        //    doesn't compete with 80s of GPU activity. Pro users only hit
        //    WhisperKit if Deepgram streaming AND batch both fail.
        //  - Unknown (first launch, no cached plan) → preload immediately
        //    to be safe.
        let cachedPlan = UserDefaults.standard.string(forKey: "lecsy.cachedPlan")
        if cachedPlan == "pro" {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                self?.prepareModelInBackground(force: true)
            }
        } else {
            prepareModelInBackground(force: true)
        }
        // Observe foreground/background transitions so the chunked
        // transcription loop can pause when iOS revokes GPU access.
        setupAppStateObservers()
    }

    deinit {
        if let t = backgroundObserverToken { NotificationCenter.default.removeObserver(t) }
        if let t = foregroundObserverToken { NotificationCenter.default.removeObserver(t) }
    }

    // MARK: - App-state observers

    private func setupAppStateObservers() {
        let nc = NotificationCenter.default
        backgroundObserverToken = nc.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isAppActive {
                    self.isAppActive = false
                    AppLogger.info("Transcription: app resigned active — will pause before next chunk", category: .transcription)
                }
            }
        }
        foregroundObserverToken = nc.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isAppActive {
                    self.isAppActive = true
                    AppLogger.info("Transcription: app active again — resuming chunk loop", category: .transcription)
                }
                // Always resume any waiting continuation on activation.
                if let cont = self.foregroundContinuation {
                    self.foregroundContinuation = nil
                    cont.resume()
                }
            }
        }
    }

    /// Suspend execution until the app is frontmost and allowed to submit
    /// GPU work. Returns immediately if already active. Called at safe
    /// boundaries in the chunk loop (never mid-chunk).
    private func awaitForegroundIfNeeded() async {
        if isAppActive { return }
        AppLogger.info("Transcription: pausing — waiting for app to become active", category: .transcription)
        downloadStatusText = "Paused — return to the app to continue transcribing"
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // Race-safe: re-check on main actor before storing.
            if isAppActive {
                cont.resume()
            } else {
                foregroundContinuation = cont
            }
        }
    }

    // MARK: - Migration from English-only (.en) models

    /// Migrate users who had base.en / small.en to the new multilingual model names.
    /// Clears the old English-only cache so the multilingual model will be downloaded fresh.
    private func migrateFromEnglishOnlyModels() {
        let migrationKey = "lecsy.didMigrateToMultilingualModels"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let defaults = UserDefaults.standard
        let oldModelName = defaults.string(forKey: "lecsy.activeModelName")

        // Check if user had an English-only model
        let hadEnglishOnlyModel = oldModelName?.hasSuffix(".en") == true

        if hadEnglishOnlyModel {
            AppLogger.info("Migrating from English-only model (\(oldModelName ?? "")) to multilingual", category: .transcription)

            // Map old model name to new multilingual equivalent
            let newModelName: String
            if oldModelName == "small.en" {
                newModelName = Self.upgradeModel // "small"
            } else {
                newModelName = Self.downloadModel // "base"
            }

            // Update stored model name FIRST (atomic-safe: if crash happens here,
            // next launch will see the flag is not set and retry migration)
            defaults.set(newModelName, forKey: "lecsy.activeModelName")

            // Clear old English-only model cache — it's incompatible
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            for dir in ["WhisperKit", "huggingface"] {
                let path = cacheDir.appendingPathComponent(dir)
                if FileManager.default.fileExists(atPath: path.path) {
                    try? FileManager.default.removeItem(at: path)
                    AppLogger.info("Cleared old .en model cache: \(dir)", category: .transcription)
                }
            }

            AppLogger.info("Model name migrated: \(oldModelName ?? "") → \(newModelName)", category: .transcription)
        }

        // Set migration flag LAST — if we crash before this, migration retries on next launch
        defaults.set(true, forKey: migrationKey)
    }

    /// Notification posted when transcription language changes
    static let languageDidChangeNotification = Notification.Name("lecsy.transcriptionLanguageDidChange")

    /// Set transcription language and persist preference
    func setLanguage(_ language: TranscriptionLanguage) {
        // Reject extended languages if multilingual kit is not installed
        guard !language.requiresMultilingualKit || isMultilingualKitInstalled else {
            AppLogger.warning("Cannot set language \(language.displayName) — multilingual kit not installed", category: .transcription)
            return
        }
        transcriptionLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "lecsy.transcriptionLanguage")
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
        AppLogger.info("Transcription language set to \(language.displayName)", category: .transcription)
    }

    /// Check if a specific model is cached
    private func isModelCached(_ modelName: String) -> Bool {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // WhisperKit caches models under huggingface/ or WhisperKit/
        for dir in ["huggingface", "WhisperKit"] {
            let path = cacheDir.appendingPathComponent(dir)
            if FileManager.default.fileExists(atPath: path.path) {
                // Check if the model folder contains the expected model name
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: path.path) {
                    for item in contents {
                        if item.lowercased().contains(modelName.replacingOccurrences(of: ".", with: "")) {
                            return true
                        }
                    }
                }
                // If we can't check contents, assume the cache is for the current model
                return true
            }
        }
        return false
    }

    /// Check if model is available (bundled or cached)
    func isModelAvailable() -> Bool {
        if bundledModelPath != nil { return true }
        if isModelLoaded { return true }
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let whisperDir = cacheDir.appendingPathComponent("huggingface")
        if FileManager.default.fileExists(atPath: whisperDir.path) { return true }
        let whisperKitDir = cacheDir.appendingPathComponent("WhisperKit")
        return FileManager.default.fileExists(atPath: whisperKitDir.path)
    }

    /// Remove old downloaded cache when bundled model is available.
    /// Frees ~460MB for users upgrading from download-based versions.
    /// Cleans both Caches/ and Documents/ where WhisperKit may have stored models.
    private func cleanUpOldCacheIfNeeded() {
        let key = "lecsy.didCleanOldModelCache.bundled.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let fm = FileManager.default
        var cleaned = false
        // WhisperKit stores models in both Caches and Documents depending on version
        let searchDirs = [
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
        ].compactMap { $0 }
        for baseDir in searchDirs {
            for subdir in ["WhisperKit", "huggingface"] {
                let path = baseDir.appendingPathComponent(subdir)
                if fm.fileExists(atPath: path.path) {
                    try? fm.removeItem(at: path)
                    AppLogger.info("Cleaned up old model: \(baseDir.lastPathComponent)/\(subdir)", category: .transcription)
                    cleaned = true
                }
            }
        }
        if cleaned {
            UserDefaults.standard.removeObject(forKey: "lecsy.activeModelName")
            UserDefaults.standard.removeObject(forKey: "lecsy.didUpgradeModel")
            AppLogger.info("Migrated from download-based to bundled model", category: .transcription)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Upgrade to a better model (download small multilingual)
    func upgradeModel() async throws {
        guard canUpgradeModel else { return }

        // Unload current model
        whisperKit = nil
        whisperKit2 = nil
        isModelLoaded = false

        state = .downloading
        progress = 0
        downloadElapsedSeconds = 0
        downloadStatusText = "Downloading improved model (~460 MB)..."

        startElapsedTimer()

        do {
            let upgradeCompute = ModelComputeOptions(
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            )
            let config = WhisperKitConfig(model: Self.upgradeModel, computeOptions: upgradeCompute)
            whisperKit = try await withTimeout(seconds: modelLoadTimeout) {
                try await WhisperKit(config)
            }
            stopElapsedTimer()

            isModelLoaded = true
            state = .idle
            progress = 1.0
            downloadStatusText = "AI model ready"
            UserDefaults.standard.set(Self.upgradeModel, forKey: "lecsy.activeModelName")
            UserDefaults.standard.set(true, forKey: "lecsy.didUpgradeModel")
            AppLogger.info("Model upgraded to \(Self.upgradeModel)", category: .transcription)
            updateMultilingualKitStatus()
        } catch {
            stopElapsedTimer()
            state = .failed
            downloadStatusText = "Upgrade failed"
            // Reload old model so user can still transcribe
            try? await loadModel()
            throw error
        }
    }

    // MARK: - Multilingual Kit

    /// Update whether the multilingual kit (small model) is installed
    private func updateMultilingualKitStatus() {
        if isModelBundled {
            // Bundled model is "small" — kit always available
            isMultilingualKitInstalled = true
        } else {
            let activeModel = UserDefaults.standard.string(forKey: "lecsy.activeModelName") ?? Self.downloadModel
            // Kit is installed if: model is "small" AND (currently loaded in memory OR cached on disk)
            isMultilingualKitInstalled = activeModel == Self.upgradeModel && (isModelLoaded || isModelCached(Self.upgradeModel))
        }
    }

    /// Download the multilingual kit (small model) to unlock extended languages
    func downloadMultilingualKit() async {
        guard !isMultilingualKitInstalled else { return }
        guard !isDownloadingMultilingualKit else { return }

        isDownloadingMultilingualKit = true
        multilingualKitDownloadFailed = false

        // Unload current model
        whisperKit = nil
        whisperKit2 = nil
        isModelLoaded = false

        state = .downloading
        progress = 0
        downloadElapsedSeconds = 0
        downloadStatusText = "Downloading Multilingual Kit (~460 MB)..."

        startElapsedTimer()

        do {
            let upgradeCompute = ModelComputeOptions(
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            )
            let config = WhisperKitConfig(model: Self.upgradeModel, computeOptions: upgradeCompute)
            whisperKit = try await withTimeout(seconds: modelLoadTimeout) {
                try await WhisperKit(config)
            }
            stopElapsedTimer()

            isModelLoaded = true
            state = .idle
            progress = 1.0
            downloadStatusText = "AI model ready"
            UserDefaults.standard.set(Self.upgradeModel, forKey: "lecsy.activeModelName")
            UserDefaults.standard.set(true, forKey: "lecsy.didUpgradeModel")
            isDownloadingMultilingualKit = false
            // Directly set installed — model is loaded in memory, no need to check cache
            isMultilingualKitInstalled = true
            AppLogger.info("Multilingual kit installed (\(Self.upgradeModel))", category: .transcription)
        } catch {
            stopElapsedTimer()
            state = .failed
            downloadStatusText = "Download failed"
            multilingualKitDownloadFailed = true
            isDownloadingMultilingualKit = false
            // Reload old model so user can still transcribe
            try? await loadModel()
            AppLogger.error("Multilingual kit download failed: \(error)", category: .transcription)
        }
    }

    /// Check Wi-Fi status asynchronously (safe for @MainActor)
    nonisolated func checkIsOnWiFi() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.usesInterfaceType(.wifi))
            }
            monitor.start(queue: DispatchQueue(label: "lecsy.wifi.check"))
        }
    }

    /// Preload the model in the background (non-blocking).
    /// Call this on app launch so the model is ready before the user's first transcription.
    /// For bundled models: loads from disk into memory (10-30s for CoreML compilation).
    /// For downloaded models: downloads first if needed (Wi-Fi only unless forced).
    func prepareModelInBackground(force: Bool = false) {
        guard !isModelLoaded else { return }
        guard modelDownloadTask == nil else { return }
        guard state != .downloading && state != .processing else { return }

        AppLogger.info("Starting background model preparation (bundled: \(isModelBundled), force: \(force))", category: .transcription)

        modelDownloadTask = Task {
            // For non-bundled models, check Wi-Fi unless forced
            if !isModelBundled && !force {
                let onWiFi = await checkIsOnWiFi()
                if !onWiFi {
                    AppLogger.info("Skipping background download — not on Wi-Fi", category: .transcription)
                    modelDownloadTask = nil
                    return
                }
            }

            do {
                try await loadModelCore()
                AppLogger.info("Background model preparation completed", category: .transcription)
            } catch {
                AppLogger.warning("Background model preparation failed: \(error)", category: .transcription)
                modelDownloadTask = nil
                throw error
            }
        }
    }

    /// Load model — public entry point.
    /// If a background download is in progress, piggybacks on it instead of starting a new one.
    func loadModel() async throws {
        guard !isModelLoaded else { return }

        // If a background download is in progress, piggyback on it
        if let existingTask = modelDownloadTask {
            AppLogger.debug("Model download already in progress, waiting...", category: .transcription)
            try await existingTask.value
            // After waiting, check if model is now loaded
            if isModelLoaded { return }
            // If not (e.g., background task skipped due to no Wi-Fi), fall through to download
        }

        try await loadModelCore()
    }

    /// Core model loading logic. Handles progress tracking, download, and retry.
    private func loadModelCore() async throws {
        guard !isModelLoaded else { return }

        state = .downloading
        progress = 0
        downloadElapsedSeconds = 0
        downloadStatusText = "Preparing AI model..."

        do {
            try await loadModelInternal()
            modelDownloadTask = nil
        } catch {
            // If loading fails (e.g. corrupted cache), clear cache and retry once
            AppLogger.warning("Model load failed, clearing cache and retrying: \(error)", category: .transcription)
            try? clearModelCache()
            do {
                try await loadModelInternal()
                modelDownloadTask = nil
            } catch is TimeoutError {
                stopElapsedTimer()
                state = .failed
                modelDownloadTask = nil
                downloadStatusText = "Download timed out"
                throw TranscriptionError.modelLoadFailed("Model loading timed out. Please check your network connection and try again.")
            } catch {
                stopElapsedTimer()
                state = .failed
                modelDownloadTask = nil
                downloadStatusText = "Download failed"
                throw TranscriptionError.modelLoadFailed(error.localizedDescription)
            }
        }
    }

    private func loadModelInternal() async throws {
        AppLogger.debug("Loading WhisperKit model (\(preferredModel))", category: .transcription)

        // Use ANE (Apple Neural Engine) for faster model loading & inference
        // ANE for encoder (compute-heavy), GPU for decoder (faster compile, good perf)
        let compute = ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndGPU
        )

        if let bundledPath = bundledModelPath {
            downloadStatusText = "Loading bundled model..."
            let loadStart = CFAbsoluteTimeGetCurrent()
            AppLogger.debug("Using bundled model at: \(bundledPath)", category: .transcription)
            whisperKit = try await WhisperKit(WhisperKitConfig(
                modelFolder: bundledPath,
                computeOptions: compute
            ))
        } else {
            let cached = isModelAvailable()
            downloadStatusText = cached ? "Loading AI model..." : "Downloading AI model (~460 MB)..."
            AppLogger.debug(cached ? "Loading cached model: \(preferredModel)" : "Downloading model: \(preferredModel)", category: .transcription)

            // Only show elapsed timer for actual network downloads, not cache loads
            if !cached {
                startElapsedTimer()
            }

            let config = WhisperKitConfig(
                model: preferredModel,
                computeOptions: compute
            )
            whisperKit = try await withTimeout(seconds: modelLoadTimeout) {
                try await WhisperKit(config)
            }

            if !cached {
                stopElapsedTimer()
            }
        }

        isModelLoaded = true
        state = .idle
        progress = 1.0
        downloadStatusText = "AI model ready"
        UserDefaults.standard.set(preferredModel, forKey: "lecsy.activeModelName")
        UserDefaults.standard.set(true, forKey: "lecsy.hasCompletedFirstModelLoad")
        updateMultilingualKitStatus()
        AppLogger.info("WhisperKit model loading completed (\(preferredModel))", category: .transcription)

        // Load second instance for parallel chunk processing on capable devices (>=6GB RAM).
        // ~244MB extra footprint for the small model — safe on A16+/iPhone 14 Pro and newer.
        if Self.shouldUseDualInstance && whisperKit2 == nil {
            Task { [weak self] in
                await self?.loadSecondInstance()
            }
        }
    }

    /// Capable-device check: skip second instance on iPhone 12 and below.
    private static var shouldUseDualInstance: Bool {
        ProcessInfo.processInfo.physicalMemory >= 6_000_000_000
    }

    /// Load the second WhisperKit instance (best-effort; failure is non-fatal).
    private func loadSecondInstance() async {
        guard whisperKit2 == nil else { return }
        let compute = ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndGPU
        )
        do {
            if let bundledPath = bundledModelPath {
                whisperKit2 = try await WhisperKit(WhisperKitConfig(
                    modelFolder: bundledPath,
                    computeOptions: compute
                ))
            } else {
                whisperKit2 = try await WhisperKit(WhisperKitConfig(
                    model: preferredModel,
                    computeOptions: compute
                ))
            }
            AppLogger.info("Second WhisperKit instance loaded for parallel chunks", category: .transcription)
        } catch {
            AppLogger.warning("Second WhisperKit instance failed to load: \(error)", category: .transcription)
            whisperKit2 = nil
        }
    }

    /// Eagerly preload the model into memory. Safe to call multiple times concurrently;
    /// returns immediately if already loaded or in-progress.
    func warmupModel() async {
        if isModelLoaded && whisperKit != nil { return }
        if let existing = warmupTask {
            await existing.value
            return
        }
        let task = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.loadModel()
            } catch {
                AppLogger.warning("warmupModel failed: \(error)", category: .transcription)
            }
        }
        warmupTask = task
        await task.value
        warmupTask = nil
    }

    /// Track elapsed time during download (no fake progress)
    private func startElapsedTimer() {
        downloadElapsedSeconds = 0
        progress = 0 // Keep at 0 — UI will show indeterminate indicator
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state == .downloading else { return }
                self.downloadElapsedSeconds += 1
            }
        }
    }

    private func stopElapsedTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        downloadElapsedSeconds = 0
    }

    /// Execute async operation with timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }

    /// Callback for progressive chunk results (lectureId, partial text, partial segments)
    var onChunkCompleted: ((_ partialText: String, _ partialSegments: [TranscriptionResult.TranscriptionSegment]) -> Void)?

    /// Execute transcription
    private var activeTranscriptionURL: URL?

    func transcribe(audioURL: URL, lectureId: UUID? = nil) async throws -> TranscriptionResult {
        // Prevent duplicate transcription of the same file
        if activeTranscriptionURL == audioURL {
            AppLogger.warning("Transcription already in progress for: \(audioURL.lastPathComponent)", category: .transcription)
            throw TranscriptionError.alreadyProcessing
        }
        activeTranscriptionURL = audioURL
        defer { activeTranscriptionURL = nil }

        // #1: Pre-process audio — high-pass filter + RMS normalization.
        // Removes low-frequency HVAC rumble and boosts quiet recordings so
        // Whisper hallucinates less.
        //
        // SAFETY GUARDS:
        //  - Run on a detached background task so the per-sample loop
        //    never blocks the main actor (this service is @MainActor).
        //  - Skip preprocessing for recordings longer than 15 minutes:
        //    loading a 60-min PCM buffer into RAM would OOM-kill the app.
        //  - Any failure silently falls back to the original audio.
        let workingURL: URL
        if let size = try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64,
           size < 50_000_000 { // ~15 min @ 64kbps AAC ≈ 7 MB; cap at 50 MB for safety
            let processed = await Task.detached(priority: .userInitiated) { [weak self] () -> URL? in
                guard let self = self else { return nil }
                return try? await self.preprocessAudioIfBeneficial(sourceURL: audioURL)
            }.value
            workingURL = processed ?? audioURL
        } else {
            AppLogger.info("Skipping audio preprocessing for large file (>50MB)", category: .transcription)
            workingURL = audioURL
        }
        defer {
            if workingURL != audioURL {
                try? FileManager.default.removeItem(at: workingURL)
            }
        }

        // Validate audio file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error("Audio file not found: \(audioURL.path)", category: .transcription)
            throw TranscriptionError.audioFileNotFound
        }

        // Validate file size
        let fileSize: Int64
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            fileSize = fileAttributes[.size] as? Int64 ?? 0
        } catch {
            AppLogger.error("Cannot read audio file attributes: \(error)", category: .transcription)
            throw TranscriptionError.audioLoadFailed
        }

        if fileSize == 0 {
            AppLogger.error("Audio file is empty (0 bytes)", category: .transcription)
            throw TranscriptionError.audioLoadFailed
        }

        AppLogger.debug("Audio file size: \(fileSize) bytes", category: .transcription)

        // Get audio duration
        let audioDuration: TimeInterval
        do {
            let asset = AVURLAsset(url: audioURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds
            if durationSeconds.isNaN || durationSeconds < 1.0 {
                AppLogger.warning("Audio too short: \(durationSeconds)s", category: .transcription)
                throw TranscriptionError.audioFileTooShort
            }
            audioDuration = durationSeconds
        } catch let error as TranscriptionError {
            throw error
        } catch {
            AppLogger.warning("Could not check audio duration: \(error)", category: .transcription)
            audioDuration = 0 // Will process as single file
        }

        // Automatically load model if not loaded
        if whisperKit == nil {
            try await loadModel()
        }

        guard let currentKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        state = .processing
        progress = 0

        var decodeOptions = DecodingOptions()
        decodeOptions.language = transcriptionLanguage.rawValue
        decodeOptions.usePrefillPrompt = true
        decodeOptions.detectLanguage = false
        // Anti-loop settings: prevent Whisper from hallucinating/repeating
        // Loosened thresholds to prevent mid-audio dropouts. The previous
        // values were aggressive enough that real speech (especially in
        // middle chunks with natural pauses) was being thrown away.
        decodeOptions.compressionRatioThreshold = 2.8 // Less eager to flag as "repetition"
        decodeOptions.logProbThreshold = -1.5 // Keep more lower-confidence segments
        decodeOptions.noSpeechThreshold = 0.8 // Only drop clearly-silent audio
        decodeOptions.temperatureFallbackCount = 3 // More retries → better recovery when fallback fires
        decodeOptions.temperature = 0 // Start greedy; fallback bumps temperature

        // Lecture context prompt — helps Whisper with academic vocabulary,
        // proper nouns, and accented speakers by setting expectations
        if let tokenizer = currentKit.tokenizer {
            let prompt = transcriptionLanguage.lecturePrompt
            decodeOptions.promptTokens = tokenizer.encode(text: prompt)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        }

        AppLogger.debug("Starting transcription (\(preferredModel)), duration: \(String(format: "%.0f", audioDuration))s", category: .transcription)

        // Short audio → process whole file directly
        // Note: if audioDuration == 0 (couldn't determine), still use chunked path
        // to avoid a potential infinite Whisper loop on a long file
        if audioDuration > 0 && audioDuration <= shortAudioThreshold {
            do {
                return try await runSingleTranscription(whisperKit: currentKit, audioURL: workingURL, decodeOptions: decodeOptions)
            } catch is TimeoutError {
                state = .failed
                throw TranscriptionError.transcriptionTimedOut
            } catch {
                state = .failed
                throw error
            }
        }

        // Long audio → chunked transcription
        // If duration is unknown, estimate from file size (64kbps AAC ≈ 8KB/s)
        let effectiveDuration: TimeInterval
        if audioDuration > 0 {
            effectiveDuration = audioDuration
        } else {
            let estimatedDuration = Double(fileSize) / 8000.0
            effectiveDuration = max(estimatedDuration, chunkDuration * 2)
            AppLogger.warning("Audio duration unknown, estimating from file size: \(String(format: "%.0f", effectiveDuration))s", category: .transcription)
        }

        do {
            return try await runChunkedTranscription(whisperKit: currentKit, audioURL: workingURL, decodeOptions: decodeOptions, totalDuration: effectiveDuration, lectureId: lectureId)
        } catch is TimeoutError {
            state = .failed
            throw TranscriptionError.transcriptionTimedOut
        } catch {
            state = .failed
            throw error
        }
    }

    // MARK: - Single File Transcription

    /// Transcribe a short audio file in one pass
    private func runSingleTranscription(whisperKit: WhisperKit, audioURL: URL, decodeOptions: DecodingOptions) async throws -> TranscriptionResult {
        let whisperResults = try await withTimeout(seconds: perChunkTimeout) {
            try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: decodeOptions
            )
        }

        guard let whisperResult = whisperResults.first else {
            AppLogger.error("WhisperKit returned no results", category: .transcription)
            throw TranscriptionError.emptyTranscriptionResult
        }

        let segments = whisperResult.segments.map { segment in
            TranscriptionResult.TranscriptionSegment(
                startTime: Double(segment.start),
                endTime: Double(segment.end),
                text: Self.stripWhisperTokens(segment.text)
            )
        }

        let fullText = Self.stripWhisperTokens(whisperResult.text)

        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AppLogger.warning("Transcription produced empty text", category: .transcription)
            throw TranscriptionError.emptyTranscriptionResult
        }

        state = .completed
        progress = 1.0
        onChunkCompleted = nil

        return TranscriptionResult(
            text: fullText,
            segments: segments,
            language: whisperResult.language,
            processingTime: 0.0
        )
    }

    // MARK: - Chunked Transcription

    /// Transcribe long audio by splitting into chunks
    private func runChunkedTranscription(whisperKit initialWhisperKit: WhisperKit, audioURL: URL, decodeOptions: DecodingOptions, totalDuration: TimeInterval, lectureId: UUID? = nil) async throws -> TranscriptionResult {
        // Request extra background execution time so iOS doesn't kill us
        // the instant the user leaves the app. The standard Background Task
        // API only grants ~30 seconds, which is why we ALSO start a silent
        // audio keep-alive below — that leverages the "audio" background
        // mode to keep the app running for the full duration of the job.
        var bgTaskId: UIBackgroundTaskIdentifier = .invalid
        bgTaskId = await UIApplication.shared.beginBackgroundTask(withName: "lecsy.transcription") {
            Task { @MainActor in
                if bgTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskId)
                    bgTaskId = .invalid
                }
            }
        }
        // Start the silent-audio keep-alive so a long (potentially 1-hour)
        // transcription can continue running even when the user switches to
        // another app or locks the screen. Stopped automatically via defer.
        BackgroundKeepAlive.shared.begin()
        defer {
            BackgroundKeepAlive.shared.end()
            if bgTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskId)
            }
        }
        var whisperKit = initialWhisperKit

        // Build progressive chunk boundaries: first chunk is short (15s) so users see
        // text fast, subsequent chunks are full-size (45s).
        var rawBoundaries: [(start: TimeInterval, end: TimeInterval)] = []
        var cursor: TimeInterval = 0
        var isFirst = true
        while cursor < totalDuration {
            let dur = isFirst ? firstChunkDuration : chunkDuration
            let end = min(cursor + dur, totalDuration)
            rawBoundaries.append((start: cursor, end: end))
            if end >= totalDuration { break }
            cursor = end - chunkOverlap
            isFirst = false
        }

        // Snap chunk boundaries (except the very first start at 0) to the nearest silence
        // so we don't cut mid-word. Costs ~50-100ms per boundary but improves accuracy.
        var audioFileCache: AVAudioFile?
        if rawBoundaries.count > 1 {
            audioFileCache = try? AVAudioFile(forReading: audioURL)
        }
        var refined: [(start: TimeInterval, end: TimeInterval)] = []
        for (i, b) in rawBoundaries.enumerated() {
            var start = b.start
            var end = b.end
            // Refine end (which becomes the next chunk's pre-overlap start)
            if i < rawBoundaries.count - 1 {
                end = await findNearestSilence(in: audioURL, near: end, cachedFile: audioFileCache)
            }
            // Refine start to match prior chunk's refined end (minus overlap)
            if i > 0 {
                let prior = refined[i - 1].end
                start = max(0, prior - chunkOverlap)
            }
            if end - start > 0.5 {
                refined.append((start: start, end: end))
            }
        }
        let chunks = refined.isEmpty ? rawBoundaries : refined
        audioFileCache = nil

        let totalChunks = chunks.count
        AppLogger.info("Chunked transcription: \(totalChunks) chunks for \(String(format: "%.0f", totalDuration))s audio", category: .transcription)

        var allSegments: [TranscriptionResult.TranscriptionSegment] = []
        // Running transcript text accumulated incrementally. This replaces
        // the old pattern of calling `allSegments.map(\.text).joined(separator:)`
        // on every chunk completion, which was O(n²) and caused long lectures
        // (120 min ≈ 3000+ segments) to spend increasing amounts of time
        // rebuilding the same string over and over. Appending keeps it O(1)
        // amortized per chunk and prevents transcription from slowing down
        // toward the end of a long recording.
        var runningText = ""
        var detectedLanguage: String?
        var consecutiveFailures = 0
        let maxConsecutiveFailures = 3

        // Helper: append a segment to both allSegments and runningText in
        // lock-step, so the two stay consistent.
        func appendSegment(_ seg: TranscriptionResult.TranscriptionSegment) {
            allSegments.append(seg)
            if runningText.isEmpty {
                runningText = seg.text
            } else {
                runningText += " " + seg.text
            }
        }

        // Keep the base prompt tokens (lecture glossary) so we can layer the
        // running transcript tail on top for subsequent chunks.
        let basePromptTokens: [Int] = decodeOptions.promptTokens ?? []

        // Helper: build decodeOptions for a chunk that should receive the
        // tail of the prior chunk's text as context. Concatenates
        // baseTokens + encoded tail text, clipped to ~200 total tokens to
        // stay under Whisper's ~224 prompt budget.
        func decodeOptionsWithContext(priorText: String) -> DecodingOptions {
            var opts = decodeOptions
            guard !priorText.isEmpty, let tokenizer = whisperKit.tokenizer else { return opts }
            // Take the last ~150 characters of prior text — roughly 30-50
            // tokens, enough for one or two sentences of context.
            let tail: String
            if priorText.count > 150 {
                tail = String(priorText.suffix(150))
            } else {
                tail = priorText
            }
            let tailTokens = tokenizer.encode(text: " " + tail)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            var combined = basePromptTokens + tailTokens
            if combined.count > 200 {
                combined = Array(combined.suffix(200))
            }
            opts.promptTokens = combined
            return opts
        }

        // Process chunks. If a second WhisperKit instance is available, process pairs concurrently.
        var index = 0
        while index < totalChunks {
            // Cooperative cancellation: if the enclosing Task (e.g. from
            // RecordView / LectureDetailView) has been cancelled, stop
            // processing immediately so we free resources and don't keep
            // burning CPU/memory for a transcription the user doesn't want
            // anymore. Cached chunks up to this point remain in the resume
            // cache, so the user can pick up where they left off.
            try Task.checkCancellation()

            // Pause at chunk boundary if the app has been backgrounded.
            // GPU command submission is blocked in background (see the
            // long comment on `isAppActive`) so there is nothing we can
            // do but wait for the user to return.
            await awaitForegroundIfNeeded()
            try Task.checkCancellation()

            let useDual = (whisperKit2 != nil) && (index + 1 < totalChunks)

            if useDual, let kit2 = whisperKit2 {
                let i1 = index
                let i2 = index + 1
                let c1 = chunks[i1]
                let c2 = chunks[i2]

                progress = Double(i1) / Double(totalChunks)
                downloadStatusText = "Transcribing parts \(i1 + 1)–\(i2 + 1) of \(totalChunks)..."

                // Resume cache: if we already processed these chunks in a
                // previous run (e.g. user killed the app mid-transcription),
                // reuse the cached segments instead of re-running Whisper.
                if let cached1 = cachedSegments(lectureId: lectureId, start: c1.start, end: c1.end),
                   let cached2 = cachedSegments(lectureId: lectureId, start: c2.start, end: c2.end) {
                    AppLogger.info("Cache hit for chunks \(i1 + 1)&\(i2 + 1) — skipping", category: .transcription)
                    for seg in cached1 + cached2 {
                        if shouldSkipDuplicate(seg, lastSeg: allSegments.last) { continue }
                        appendSegment(seg)
                    }
                    onChunkCompleted?(runningText, allSegments)
                    index += 2
                    continue
                }

                AppLogger.debug("Processing chunks \(i1 + 1)&\(i2 + 1)/\(totalChunks) in parallel", category: .transcription)

                // Feed both parallel chunks the tail of whatever's been
                // transcribed so far. They run concurrently so they share
                // the same context snapshot (from the previous pair).
                let priorTail = allSegments.suffix(5).map(\.text).joined(separator: " ")
                let pairOptions = decodeOptionsWithContext(priorText: priorTail)

                async let r1 = transcribeTimeRangeNonInOut(
                    whisperKit: whisperKit,
                    audioURL: audioURL,
                    decodeOptions: pairOptions,
                    start: c1.start,
                    end: c1.end,
                    isOverlap: i1 > 0,
                    label: "Chunk \(i1 + 1)/\(totalChunks)"
                )
                async let r2 = transcribeTimeRangeNonInOut(
                    whisperKit: kit2,
                    audioURL: audioURL,
                    decodeOptions: pairOptions,
                    start: c2.start,
                    end: c2.end,
                    isOverlap: true,
                    label: "Chunk \(i2 + 1)/\(totalChunks)"
                )
                let result1 = await r1
                let result2 = await r2

                // Persist both chunks to the resume cache before merging so
                // a crash during the next chunk doesn't lose this work.
                if let lectureId = lectureId {
                    if !result1.didTimeout {
                        appendToChunkCache(lectureId: lectureId, start: c1.start, end: c1.end, segments: result1.segments)
                    }
                    if !result2.didTimeout {
                        appendToChunkCache(lectureId: lectureId, start: c2.start, end: c2.end, segments: result2.segments)
                    }
                }

                // Merge in chronological order (kit1 first, then kit2)
                for result in [result1, result2] {
                    if let lang = result.language, detectedLanguage == nil {
                        detectedLanguage = lang
                    }
                    for seg in result.segments {
                        if shouldSkipDuplicate(seg, lastSeg: allSegments.last) { continue }
                        appendSegment(seg)
                    }
                    if result.didTimeout { consecutiveFailures += 1 } else { consecutiveFailures = 0 }
                    onChunkCompleted?(runningText, allSegments)
                }

                if consecutiveFailures >= maxConsecutiveFailures {
                    AppLogger.warning("Too many consecutive timeouts — reloading WhisperKit model", category: .transcription)
                    self.whisperKit = nil
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    do {
                        try await loadModelInternal()
                        if let reloaded = self.whisperKit { whisperKit = reloaded }
                    } catch {
                        AppLogger.error("Failed to reload model: \(error)", category: .transcription)
                    }
                    consecutiveFailures = 0
                }

                index += 2
                if index < totalChunks {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
                continue
            }

            // Single-instance fallback path
            let chunk = chunks[index]
            progress = Double(index) / Double(totalChunks)
            downloadStatusText = "Transcribing part \(index + 1) of \(totalChunks)..."

            AppLogger.debug("Processing chunk \(index + 1)/\(totalChunks): \(String(format: "%.0f", chunk.start))s - \(String(format: "%.0f", chunk.end))s", category: .transcription)

            // Resume cache: reuse segments processed in a previous run.
            if let cached = cachedSegments(lectureId: lectureId, start: chunk.start, end: chunk.end) {
                AppLogger.info("Cache hit for chunk \(index + 1) — skipping", category: .transcription)
                for seg in cached {
                    if shouldSkipDuplicate(seg, lastSeg: allSegments.last) { continue }
                    appendSegment(seg)
                }
                onChunkCompleted?(runningText, allSegments)
                index += 1
                continue
            }

            // Feed this chunk the tail of everything we've transcribed so
            // far as prompt context. For the first chunk this is empty and
            // we fall back to the base lecture glossary prompt.
            let priorTail = allSegments.suffix(5).map(\.text).joined(separator: " ")
            let chunkOptions = decodeOptionsWithContext(priorText: priorTail)

            let result = await transcribeTimeRange(
                whisperKit: &whisperKit,
                audioURL: audioURL,
                decodeOptions: chunkOptions,
                start: chunk.start,
                end: chunk.end,
                isOverlap: index > 0,
                label: "Chunk \(index + 1)/\(totalChunks)"
            )

            if let lectureId = lectureId, !result.didTimeout {
                appendToChunkCache(lectureId: lectureId, start: chunk.start, end: chunk.end, segments: result.segments)
            }

            if let lang = result.language, detectedLanguage == nil {
                detectedLanguage = lang
            }

            for seg in result.segments {
                if shouldSkipDuplicate(seg, lastSeg: allSegments.last) { continue }
                appendSegment(seg)
            }

            if result.didTimeout {
                consecutiveFailures += 1
                if consecutiveFailures >= maxConsecutiveFailures {
                    AppLogger.warning("Too many consecutive timeouts — reloading WhisperKit model", category: .transcription)
                    self.whisperKit = nil
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    do {
                        try await loadModelInternal()
                        if let reloaded = self.whisperKit { whisperKit = reloaded }
                    } catch {
                        AppLogger.error("Failed to reload model: \(error)", category: .transcription)
                    }
                    consecutiveFailures = 0
                }
            } else {
                consecutiveFailures = 0
            }

            onChunkCompleted?(runningText, allSegments)

            if index < totalChunks - 1 {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            index += 1
        }

        // Build final result — runningText has been accumulated
        // incrementally throughout the loop, so no O(n) rebuild here.
        let fullText = runningText

        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AppLogger.warning("Chunked transcription produced empty text", category: .transcription)
            throw TranscriptionError.emptyTranscriptionResult
        }

        state = .completed
        progress = 1.0
        downloadStatusText = ""
        onChunkCompleted = nil

        AppLogger.info("Chunked transcription complete: \(allSegments.count) segments", category: .transcription)

        // Transcription finished successfully — clear the resume cache.
        if let lectureId = lectureId {
            clearChunkCache(lectureId: lectureId)
        }

        return TranscriptionResult(
            text: fullText,
            segments: allSegments,
            language: detectedLanguage,
            processingTime: 0.0
        )
    }

    /// Export a time range of audio to a temporary file
    private func exportAudioChunk(from sourceURL: URL, start: TimeInterval, end: TimeInterval, chunkIndex: Int) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        // Clamp end time to actual asset duration to avoid export failure on last chunk
        let assetDuration = try? await asset.load(.duration)
        let actualEnd: TimeInterval
        if let assetDuration, CMTimeGetSeconds(assetDuration) > 0 {
            actualEnd = min(end, CMTimeGetSeconds(assetDuration))
        } else {
            actualEnd = end
        }

        // Skip if chunk would be too short (< 0.5s)
        guard actualEnd - start > 0.5 else {
            AppLogger.debug("Chunk \(chunkIndex) too short (\(String(format: "%.1f", actualEnd - start))s), skipping export", category: .transcription)
            throw TranscriptionError.audioFileTooShort
        }

        let startTime = CMTime(seconds: start, preferredTimescale: 44100)
        let endTime = CMTime(seconds: actualEnd, preferredTimescale: 44100)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        let tempDir = FileManager.default.temporaryDirectory
        let chunkURL = tempDir.appendingPathComponent("chunk_\(chunkIndex)_\(UUID().uuidString).m4a")

        // Remove existing file if any
        try? FileManager.default.removeItem(at: chunkURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.audioLoadFailed
        }

        exportSession.outputURL = chunkURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        // Track whether the export succeeded so we only hand the file back
        // to the caller on success. On any failure path (throw, non-completed
        // status, cancelled Task) we scrub the temp file here so `/tmp` can't
        // slowly fill up over a long recording with many chunks.
        var succeeded = false
        defer {
            if !succeeded {
                try? FileManager.default.removeItem(at: chunkURL)
            }
        }

        await exportSession.export()

        // Propagate Task cancellation even if export ignored it.
        try Task.checkCancellation()

        guard exportSession.status == .completed else {
            AppLogger.error("Chunk export failed: \(exportSession.error?.localizedDescription ?? "unknown")", category: .transcription)
            throw TranscriptionError.audioLoadFailed
        }

        succeeded = true
        return chunkURL
    }

    // MARK: - Time Range Transcription (with sub-chunk retry)

    /// Transcribe a specific time range. On timeout/failure, automatically splits into
    /// smaller sub-chunks and retries each individually so no audio is permanently skipped.
    private func transcribeTimeRange(
        whisperKit: inout WhisperKit,
        audioURL: URL,
        decodeOptions: DecodingOptions,
        start: TimeInterval,
        end: TimeInterval,
        isOverlap: Bool,
        label: String
    ) async -> (segments: [TranscriptionResult.TranscriptionSegment], language: String?, didTimeout: Bool) {
        // Try transcribing the full range first
        let result = await transcribeSingleRange(
            whisperKit: whisperKit,
            audioURL: audioURL,
            decodeOptions: decodeOptions,
            start: start,
            end: end,
            timeout: perChunkTimeout,
            label: label
        )

        if let result = result {
            let segments = offsetAndFilter(segments: result.segments, offset: start, trimOverlap: isOverlap ? chunkOverlap : 0)
            return (segments: segments, language: result.language, didTimeout: false)
        }

        // Full range failed — split into ~30-second sub-chunks and retry each
        AppLogger.warning("\(label) failed, splitting into sub-chunks", category: .transcription)
        let subChunkDuration: TimeInterval = 30
        let subChunkOverlap: TimeInterval = 2
        let subChunkTimeout: TimeInterval = 60

        var subStarts = Array(stride(from: start, to: end, by: subChunkDuration - subChunkOverlap))
        if subStarts.isEmpty { subStarts = [start] }

        var allSegments: [TranscriptionResult.TranscriptionSegment] = []
        var detectedLanguage: String?
        var anyTimeout = false

        for (subIdx, subStart) in subStarts.enumerated() {
            let subEnd = min(subStart + subChunkDuration, end)
            guard subEnd - subStart > 0.5 else { continue }

            let subLabel = "\(label) sub-\(subIdx + 1)/\(subStarts.count)"
            AppLogger.debug("Processing \(subLabel): \(String(format: "%.0f", subStart))s - \(String(format: "%.0f", subEnd))s", category: .transcription)

            let subResult = await transcribeSingleRange(
                whisperKit: whisperKit,
                audioURL: audioURL,
                decodeOptions: decodeOptions,
                start: subStart,
                end: subEnd,
                timeout: subChunkTimeout,
                label: subLabel
            )

            // If the sub-chunk failed on the first pass, retry ONCE with a
            // much longer timeout before giving up. This catches cases where
            // WhisperKit just needed more time (thermal throttling, slow
            // device, huge audio). Previously these 30s would be lost.
            var finalSubResult = subResult
            if finalSubResult == nil {
                AppLogger.warning("\(subLabel) timed out — retrying with extended timeout", category: .transcription)
                try? await Task.sleep(nanoseconds: 500_000_000)
                finalSubResult = await transcribeSingleRange(
                    whisperKit: whisperKit,
                    audioURL: audioURL,
                    decodeOptions: decodeOptions,
                    start: subStart,
                    end: subEnd,
                    timeout: subChunkTimeout * 3,
                    label: "\(subLabel) retry"
                )
            }

            if let subResult = finalSubResult {
                let trimOverlap: TimeInterval = (subIdx > 0 || isOverlap) ? subChunkOverlap : 0
                let segments = offsetAndFilter(segments: subResult.segments, offset: subStart, trimOverlap: trimOverlap)
                for seg in segments {
                    if shouldSkipDuplicate(seg, lastSeg: allSegments.last) { continue }
                    allSegments.append(seg)
                }
                if let lang = subResult.language, detectedLanguage == nil {
                    detectedLanguage = lang
                }
            } else {
                // Even the retry failed — log but continue (only ~30s lost)
                anyTimeout = true
                AppLogger.error("\(subLabel) also failed after retry — skipping \(String(format: "%.0f", subEnd - subStart))s of audio", category: .transcription)
            }

            // Brief cooldown between sub-chunks
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        return (segments: allSegments, language: detectedLanguage, didTimeout: anyTimeout)
    }

    /// Non-inout variant of transcribeTimeRange for async-let parallel calls.
    /// Skips the model-reload-on-failure handling (caller does it after both branches return).
    private func transcribeTimeRangeNonInOut(
        whisperKit: WhisperKit,
        audioURL: URL,
        decodeOptions: DecodingOptions,
        start: TimeInterval,
        end: TimeInterval,
        isOverlap: Bool,
        label: String
    ) async -> (segments: [TranscriptionResult.TranscriptionSegment], language: String?, didTimeout: Bool) {
        let result = await transcribeSingleRange(
            whisperKit: whisperKit,
            audioURL: audioURL,
            decodeOptions: decodeOptions,
            start: start,
            end: end,
            timeout: perChunkTimeout,
            label: label
        )
        if let result = result {
            let segments = offsetAndFilter(segments: result.segments, offset: start, trimOverlap: isOverlap ? chunkOverlap : 0)
            return (segments: segments, language: result.language, didTimeout: false)
        }

        // Sub-chunk fallback
        let subChunkDuration: TimeInterval = 30
        let subChunkOverlap: TimeInterval = 2
        let subChunkTimeout: TimeInterval = 60
        var subStarts = Array(stride(from: start, to: end, by: subChunkDuration - subChunkOverlap))
        if subStarts.isEmpty { subStarts = [start] }

        var allSegments: [TranscriptionResult.TranscriptionSegment] = []
        var detectedLanguage: String?
        var anyTimeout = false

        for (subIdx, subStart) in subStarts.enumerated() {
            let subEnd = min(subStart + subChunkDuration, end)
            guard subEnd - subStart > 0.5 else { continue }
            let subLabel = "\(label) sub-\(subIdx + 1)/\(subStarts.count)"
            var subResult = await transcribeSingleRange(
                whisperKit: whisperKit,
                audioURL: audioURL,
                decodeOptions: decodeOptions,
                start: subStart,
                end: subEnd,
                timeout: subChunkTimeout,
                label: subLabel
            )
            if subResult == nil {
                AppLogger.warning("\(subLabel) timed out — retrying with extended timeout", category: .transcription)
                // If the failure was caused by the app being backgrounded
                // (GPU submission denied), wait for it to come back before
                // burning the retry budget on a guaranteed-failing call.
                await awaitForegroundIfNeeded()
                try? await Task.sleep(nanoseconds: 500_000_000)
                subResult = await transcribeSingleRange(
                    whisperKit: whisperKit,
                    audioURL: audioURL,
                    decodeOptions: decodeOptions,
                    start: subStart,
                    end: subEnd,
                    timeout: subChunkTimeout * 3,
                    label: "\(subLabel) retry"
                )
            }
            if let subResult = subResult {
                let trimOverlap: TimeInterval = (subIdx > 0 || isOverlap) ? subChunkOverlap : 0
                let segments = offsetAndFilter(segments: subResult.segments, offset: subStart, trimOverlap: trimOverlap)
                for seg in segments {
                    if shouldSkipDuplicate(seg, lastSeg: allSegments.last) { continue }
                    allSegments.append(seg)
                }
                if let lang = subResult.language, detectedLanguage == nil {
                    detectedLanguage = lang
                }
            } else {
                anyTimeout = true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        return (segments: allSegments, language: detectedLanguage, didTimeout: anyTimeout)
    }

    /// Find the nearest silence (lowest-RMS 200ms window) within ±searchWindow of `targetSeconds`.
    /// Returns the center time of that silence in absolute file seconds.
    /// On any read failure, returns `targetSeconds` unchanged (graceful degradation).
    private func findNearestSilence(
        in audioURL: URL,
        near targetSeconds: TimeInterval,
        searchWindow: TimeInterval = 5.0,
        cachedFile: AVAudioFile? = nil
    ) async -> TimeInterval {
        let file: AVAudioFile
        if let cachedFile = cachedFile {
            file = cachedFile
        } else {
            guard let f = try? AVAudioFile(forReading: audioURL) else { return targetSeconds }
            file = f
        }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return targetSeconds }

        let totalFrames = file.length
        let windowStartSec = max(0, targetSeconds - searchWindow)
        let windowEndSec = min(Double(totalFrames) / sampleRate, targetSeconds + searchWindow)
        guard windowEndSec > windowStartSec else { return targetSeconds }

        let startFrame = AVAudioFramePosition(windowStartSec * sampleRate)
        let endFrame = AVAudioFramePosition(windowEndSec * sampleRate)
        let frameCount = AVAudioFrameCount(endFrame - startFrame)
        guard frameCount > 0 else { return targetSeconds }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return targetSeconds
        }
        do {
            file.framePosition = startFrame
            try file.read(into: buffer, frameCount: frameCount)
        } catch {
            return targetSeconds
        }
        guard let channelData = buffer.floatChannelData else { return targetSeconds }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return targetSeconds }
        let channels = Int(format.channelCount)

        // Compute RMS over 100ms windows
        let rmsWindowFrames = max(1, Int(0.1 * sampleRate))
        let strideFrames = rmsWindowFrames
        var rms: [Float] = []
        var i = 0
        while i + rmsWindowFrames <= frames {
            var sum: Float = 0
            for c in 0..<channels {
                let ptr = channelData[c]
                for j in 0..<rmsWindowFrames {
                    let s = ptr[i + j]
                    sum += s * s
                }
            }
            let mean = sum / Float(rmsWindowFrames * channels)
            rms.append(mean.squareRoot())
            i += strideFrames
        }
        guard rms.count >= 2 else { return targetSeconds }

        // Find lowest 200ms (= 2 windows) average
        var bestIdx = 0
        var bestVal: Float = .infinity
        for k in 0..<(rms.count - 1) {
            let v = (rms[k] + rms[k + 1]) * 0.5
            if v < bestVal {
                bestVal = v
                bestIdx = k
            }
        }
        // Center of the 200ms window in absolute seconds
        let windowCenterOffset = (Double(bestIdx) + 1.0) * 0.1
        return windowStartSec + windowCenterOffset
    }

    /// Transcribe a single audio range (export + WhisperKit). Returns nil on failure.
    private func transcribeSingleRange(
        whisperKit: WhisperKit,
        audioURL: URL,
        decodeOptions: DecodingOptions,
        start: TimeInterval,
        end: TimeInterval,
        timeout: TimeInterval,
        label: String
    ) async -> (segments: [(start: Float, end: Float, text: String)], language: String?)? {
        // Export chunk
        let chunkURL: URL
        do {
            chunkURL = try await exportAudioChunk(from: audioURL, start: start, end: end, chunkIndex: Int(start))
        } catch {
            AppLogger.error("\(label) export failed: \(error)", category: .transcription)
            return nil
        }

        defer { try? FileManager.default.removeItem(at: chunkURL) }

        // Transcribe with timeout
        do {
            let whisperResults = try await withTimeout(seconds: timeout) {
                try await whisperKit.transcribe(
                    audioPath: chunkURL.path,
                    decodeOptions: decodeOptions
                )
            }

            guard let whisperResult = whisperResults.first else {
                AppLogger.warning("\(label) returned no results", category: .transcription)
                return nil
            }

            let text = Self.stripWhisperTokens(whisperResult.text)

            // Detect repetition / hallucination
            if isRepetitive(text) {
                AppLogger.warning("\(label) produced repetitive text, discarding", category: .transcription)
                return nil
            }

            let segments = whisperResult.segments.map { seg in
                (start: seg.start, end: seg.end, text: Self.stripWhisperTokens(seg.text))
            }

            return (segments: segments, language: whisperResult.language)
        } catch is TimeoutError {
            AppLogger.warning("\(label) timed out after \(Int(timeout))s", category: .transcription)
            return nil
        } catch {
            AppLogger.error("\(label) transcription error: \(error)", category: .transcription)
            return nil
        }
    }

    /// Decide whether `seg` is a duplicate of the previous segment.
    /// Previously this did a plain text-equality check against the last segment,
    /// which incorrectly dropped naturally repeated words/phrases (e.g. "Yes.",
    /// "Okay.", "So...") across chunk boundaries, creating gaps in the final
    /// transcript. We now only treat a segment as a duplicate when its time
    /// range actually overlaps the previous segment AND the text matches.
    // MARK: - Audio Preprocessing (#1)

    /// Run a high-pass filter (80 Hz biquad) and RMS normalization on the
    /// source audio before transcription. Returns the URL of a processed
    /// temporary file, or throws on failure. The caller is responsible for
    /// cleaning up the returned file.
    ///
    /// `nonisolated` + `async` so it can run on a detached background task
    /// without hopping back to the main actor — this was the cause of UI
    /// freezes during recording.
    nonisolated func preprocessAudioIfBeneficial(sourceURL: URL) async throws -> URL {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let format = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(sourceFile.length)
        guard frameCount > 0 else { return sourceURL }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return sourceURL
        }
        try sourceFile.read(into: buffer)
        guard let channelData = buffer.floatChannelData else { return sourceURL }

        let channelCount = Int(format.channelCount)
        let frames = Int(buffer.frameLength)
        let sampleRate = format.sampleRate

        // --- High-pass biquad (RBJ cookbook), cutoff 80 Hz, Q = 0.707 ---
        let cutoff: Double = 80.0
        let q: Double = 0.707
        let omega = 2.0 * .pi * cutoff / sampleRate
        let sinO = sin(omega)
        let cosO = cos(omega)
        let alpha = sinO / (2.0 * q)
        let a0 = 1.0 + alpha
        let b0 = Float(((1.0 + cosO) / 2.0) / a0)
        let b1 = Float((-(1.0 + cosO)) / a0)
        let b2 = Float(((1.0 + cosO) / 2.0) / a0)
        let a1 = Float((-2.0 * cosO) / a0)
        let a2 = Float((1.0 - alpha) / a0)

        for ch in 0..<channelCount {
            let data = channelData[ch]
            var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0
            for i in 0..<frames {
                let x0 = data[i]
                let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                data[i] = y0
                x2 = x1; x1 = x0
                y2 = y1; y1 = y0
            }
        }

        // --- RMS normalization: boost quiet recordings toward -20 dBFS ---
        var sumSq: Double = 0
        var count: Int = 0
        for ch in 0..<channelCount {
            let data = channelData[ch]
            for i in 0..<frames {
                let s = Double(data[i])
                sumSq += s * s
            }
            count += frames
        }
        let rms = sqrt(sumSq / Double(max(count, 1)))
        let targetRMS: Double = 0.1 // -20 dBFS
        if rms > 0.001 && rms < targetRMS {
            let rawGain = targetRMS / rms
            let gain = Float(min(rawGain, 6.0)) // cap at +15.6 dB
            for ch in 0..<channelCount {
                let data = channelData[ch]
                for i in 0..<frames {
                    data[i] *= gain
                }
            }
            AppLogger.debug("Audio preprocessed: RMS \(rms) → gain x\(gain)", category: .transcription)
        }

        // Soft-clip in case normalization pushed samples past [-1, 1]
        for ch in 0..<channelCount {
            let data = channelData[ch]
            for i in 0..<frames {
                let s = data[i]
                if s > 1.0 { data[i] = 1.0 }
                else if s < -1.0 { data[i] = -1.0 }
            }
        }

        // Write to a temp WAV file. WAV is lossless and Whisper handles it.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preproc_\(UUID().uuidString).wav")
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let outputFile = try AVAudioFile(forWriting: tempURL, settings: outputSettings)
        try outputFile.write(from: buffer)
        return tempURL
    }

    // MARK: - Chunk Resume Cache (#3)

    /// On-disk cache mapping "lectureId → chunk start time → processed segments".
    /// Survives crashes so long recordings can resume instead of re-processing
    /// from scratch. Cleared automatically when a lecture finishes transcribing.
    private struct CachedChunkEntry: Codable {
        let start: Double
        let end: Double
        let segments: [TranscriptionResult.TranscriptionSegment]
    }

    private func chunkCacheURL(lectureId: UUID) -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("transcription_cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(lectureId.uuidString).json")
    }

    private func loadChunkCache(lectureId: UUID) -> [CachedChunkEntry] {
        guard let url = chunkCacheURL(lectureId: lectureId),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([CachedChunkEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func appendToChunkCache(
        lectureId: UUID,
        start: Double,
        end: Double,
        segments: [TranscriptionResult.TranscriptionSegment]
    ) {
        guard let url = chunkCacheURL(lectureId: lectureId) else { return }
        var entries = loadChunkCache(lectureId: lectureId)
        // Replace any existing entry with the same start (shouldn't happen but
        // keeps the cache idempotent).
        entries.removeAll { abs($0.start - start) < 0.1 }
        entries.append(CachedChunkEntry(start: start, end: end, segments: segments))
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Remove the chunk cache for a lecture. Call when transcription has
    /// successfully finished so we don't leak disk space.
    func clearChunkCache(lectureId: UUID) {
        guard let url = chunkCacheURL(lectureId: lectureId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Return cached segments for a chunk range if present.
    private func cachedSegments(
        lectureId: UUID?,
        start: Double,
        end: Double
    ) -> [TranscriptionResult.TranscriptionSegment]? {
        guard let lectureId = lectureId else { return nil }
        let entries = loadChunkCache(lectureId: lectureId)
        return entries.first { abs($0.start - start) < 0.1 && abs($0.end - end) < 0.1 }?.segments
    }

    private func shouldSkipDuplicate(
        _ seg: TranscriptionResult.TranscriptionSegment,
        lastSeg: TranscriptionResult.TranscriptionSegment?
    ) -> Bool {
        guard let last = lastSeg else { return false }
        // Hard-drop only when this segment starts well before the end of the
        // previous one AND the text matches — that's the overlap-zone case.
        let startsBeforeLastEnds = seg.startTime < last.endTime - 0.1
        let normalizedA = seg.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedB = last.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if startsBeforeLastEnds && normalizedA == normalizedB {
            return true
        }
        return false
    }

    /// Offset segment timestamps to absolute audio position and trim overlap
    private func offsetAndFilter(
        segments: [(start: Float, end: Float, text: String)],
        offset: TimeInterval,
        trimOverlap: TimeInterval
    ) -> [TranscriptionResult.TranscriptionSegment] {
        segments.compactMap { seg in
            let absStart = Double(seg.start) + offset
            let absEnd = Double(seg.end) + offset
            // Only drop segments that lie ENTIRELY inside the overlap zone.
            // Previously any segment whose start fell in the overlap (even if
            // the bulk of it extended past) was dropped wholesale — that was
            // losing large chunks of real speech. Keep any segment that
            // extends beyond the overlap; timestamp-based dedup in the merge
            // step handles actual duplicates.
            if trimOverlap > 0 && Double(seg.end) <= trimOverlap { return nil }
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return nil }
            return TranscriptionResult.TranscriptionSegment(
                startTime: absStart,
                endTime: absEnd,
                text: text
            )
        }
    }

    /// Detect repetitive/hallucinated text (e.g. same phrase repeated many times)
    private func isRepetitive(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 50 else { return false }

        // Check if any short phrase is repeated excessively
        let words = trimmed.split(separator: " ")
        guard words.count > 10 else { return false }

        // Build trigrams and check for excessive repetition
        var trigramCounts: [String: Int] = [:]
        for i in 0..<(words.count - 2) {
            let trigram = "\(words[i]) \(words[i+1]) \(words[i+2])".lowercased()
            trigramCounts[trigram, default: 0] += 1
        }

        let maxCount = trigramCounts.values.max() ?? 0
        let totalTrigrams = max(words.count - 2, 1)
        // If any trigram appears in more than 40% of positions, it's repetitive
        return Double(maxCount) / Double(totalTrigrams) > 0.4
    }

    /// Strip Whisper special tokens like <|startoftranscript|>, <|en|>, <|0.00|>, etc.
    private static func stripWhisperTokens(_ text: String) -> String {
        text.replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cancel transcription
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        onChunkCompleted = nil
        stopElapsedTimer()
        state = .idle
        progress = 0
    }

    /// Clear cached model (keeps bundled model intact)
    func clearModelCache() throws {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for dir in ["WhisperKit", "huggingface"] {
            let path = cacheDir.appendingPathComponent(dir)
            if FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
        }
        whisperKit = nil
        whisperKit2 = nil
        isModelLoaded = false
    }
}

/// Transcription state
enum TranscriptionState {
    case idle
    case downloading
    case processing
    case completed
    case failed
}

/// Timeout error for async operations
struct TimeoutError: Error {}

/// Transcription error
enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case audioLoadFailed
    case transcriptionFailed
    case audioFileNotFound
    case audioFileTooShort
    case emptyTranscriptionResult
    case transcriptionTimedOut
    case alreadyProcessing

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded"
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .audioLoadFailed:
            return "Failed to load audio file"
        case .audioFileNotFound:
            return "Audio file not found. The recording may have been deleted."
        case .audioFileTooShort:
            return "Recording is too short. Please record for at least a few seconds."
        case .emptyTranscriptionResult:
            return "No speech was detected in the recording. Please make sure you are speaking clearly and try again."
        case .transcriptionFailed:
            return "Transcription failed"
        case .transcriptionTimedOut:
            return "Transcription timed out. The audio may be too long or the device is too slow. Please try again with a shorter recording."
        case .alreadyProcessing:
            return "Transcription is already in progress for this file."
        }
    }
}
