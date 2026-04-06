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
        // Preload model into memory immediately — don't wait for UI
        prepareModelInBackground(force: true)
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

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Prevent duplicate transcription of the same file
        if activeTranscriptionURL == audioURL {
            AppLogger.warning("Transcription already in progress for: \(audioURL.lastPathComponent)", category: .transcription)
            throw TranscriptionError.alreadyProcessing
        }
        activeTranscriptionURL = audioURL
        defer { activeTranscriptionURL = nil }

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
        decodeOptions.compressionRatioThreshold = 2.4 // Skip segments with high repetition
        decodeOptions.logProbThreshold = -1.0 // Skip low-confidence segments
        decodeOptions.noSpeechThreshold = 0.6 // Skip silence more aggressively
        decodeOptions.temperatureFallbackCount = 1 // Minimal retries for speed
        decodeOptions.temperature = 0 // Greedy decoding — fastest

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
                return try await runSingleTranscription(whisperKit: currentKit, audioURL: audioURL, decodeOptions: decodeOptions)
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
            return try await runChunkedTranscription(whisperKit: currentKit, audioURL: audioURL, decodeOptions: decodeOptions, totalDuration: effectiveDuration)
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
    private func runChunkedTranscription(whisperKit initialWhisperKit: WhisperKit, audioURL: URL, decodeOptions: DecodingOptions, totalDuration: TimeInterval) async throws -> TranscriptionResult {
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
        var detectedLanguage: String?
        var consecutiveFailures = 0
        let maxConsecutiveFailures = 3

        // Process chunks. If a second WhisperKit instance is available, process pairs concurrently.
        var index = 0
        while index < totalChunks {
            let useDual = (whisperKit2 != nil) && (index + 1 < totalChunks)

            if useDual, let kit2 = whisperKit2 {
                let i1 = index
                let i2 = index + 1
                let c1 = chunks[i1]
                let c2 = chunks[i2]

                progress = Double(i1) / Double(totalChunks)
                downloadStatusText = "Transcribing parts \(i1 + 1)–\(i2 + 1) of \(totalChunks)..."

                AppLogger.debug("Processing chunks \(i1 + 1)&\(i2 + 1)/\(totalChunks) in parallel", category: .transcription)

                async let r1 = transcribeTimeRangeNonInOut(
                    whisperKit: whisperKit,
                    audioURL: audioURL,
                    decodeOptions: decodeOptions,
                    start: c1.start,
                    end: c1.end,
                    isOverlap: i1 > 0,
                    label: "Chunk \(i1 + 1)/\(totalChunks)"
                )
                async let r2 = transcribeTimeRangeNonInOut(
                    whisperKit: kit2,
                    audioURL: audioURL,
                    decodeOptions: decodeOptions,
                    start: c2.start,
                    end: c2.end,
                    isOverlap: true,
                    label: "Chunk \(i2 + 1)/\(totalChunks)"
                )
                let result1 = await r1
                let result2 = await r2

                // Merge in chronological order (kit1 first, then kit2)
                for result in [result1, result2] {
                    if let lang = result.language, detectedLanguage == nil {
                        detectedLanguage = lang
                    }
                    for seg in result.segments {
                        if let lastSeg = allSegments.last, seg.text == lastSeg.text { continue }
                        allSegments.append(seg)
                    }
                    if result.didTimeout { consecutiveFailures += 1 } else { consecutiveFailures = 0 }
                    let partialText = allSegments.map(\.text).joined(separator: " ")
                    onChunkCompleted?(partialText, allSegments)
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

            let result = await transcribeTimeRange(
                whisperKit: &whisperKit,
                audioURL: audioURL,
                decodeOptions: decodeOptions,
                start: chunk.start,
                end: chunk.end,
                isOverlap: index > 0,
                label: "Chunk \(index + 1)/\(totalChunks)"
            )

            if let lang = result.language, detectedLanguage == nil {
                detectedLanguage = lang
            }

            for seg in result.segments {
                if let lastSeg = allSegments.last, seg.text == lastSeg.text { continue }
                allSegments.append(seg)
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

            let partialText = allSegments.map(\.text).joined(separator: " ")
            onChunkCompleted?(partialText, allSegments)

            if index < totalChunks - 1 {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            index += 1
        }

        // Build final result
        let fullText = allSegments.map(\.text).joined(separator: " ")

        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AppLogger.warning("Chunked transcription produced empty text", category: .transcription)
            throw TranscriptionError.emptyTranscriptionResult
        }

        state = .completed
        progress = 1.0
        downloadStatusText = ""
        onChunkCompleted = nil

        AppLogger.info("Chunked transcription complete: \(allSegments.count) segments", category: .transcription)

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

        await exportSession.export()

        guard exportSession.status == .completed else {
            AppLogger.error("Chunk export failed: \(exportSession.error?.localizedDescription ?? "unknown")", category: .transcription)
            throw TranscriptionError.audioLoadFailed
        }

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

            if let subResult = subResult {
                let trimOverlap: TimeInterval = (subIdx > 0 || isOverlap) ? subChunkOverlap : 0
                let segments = offsetAndFilter(segments: subResult.segments, offset: subStart, trimOverlap: trimOverlap)
                for seg in segments {
                    if let last = allSegments.last, seg.text == last.text { continue }
                    allSegments.append(seg)
                }
                if let lang = subResult.language, detectedLanguage == nil {
                    detectedLanguage = lang
                }
            } else {
                // Even sub-chunk failed — log but continue (only ~30s lost)
                anyTimeout = true
                AppLogger.error("\(subLabel) also failed — skipping \(String(format: "%.0f", subEnd - subStart))s of audio", category: .transcription)
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
            let subResult = await transcribeSingleRange(
                whisperKit: whisperKit,
                audioURL: audioURL,
                decodeOptions: decodeOptions,
                start: subStart,
                end: subEnd,
                timeout: subChunkTimeout,
                label: subLabel
            )
            if let subResult = subResult {
                let trimOverlap: TimeInterval = (subIdx > 0 || isOverlap) ? subChunkOverlap : 0
                let segments = offsetAndFilter(segments: subResult.segments, offset: subStart, trimOverlap: trimOverlap)
                for seg in segments {
                    if let last = allSegments.last, seg.text == last.text { continue }
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

    /// Offset segment timestamps to absolute audio position and trim overlap
    private func offsetAndFilter(
        segments: [(start: Float, end: Float, text: String)],
        offset: TimeInterval,
        trimOverlap: TimeInterval
    ) -> [TranscriptionResult.TranscriptionSegment] {
        segments.compactMap { seg in
            let absStart = Double(seg.start) + offset
            let absEnd = Double(seg.end) + offset
            // If this chunk has overlap, skip segments that fall within the overlap zone
            if trimOverlap > 0 && Double(seg.start) < trimOverlap { return nil }
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
