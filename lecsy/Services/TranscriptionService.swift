//
//  TranscriptionService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import WhisperKit
import AVFoundation
import Combine

/// Transcription service
@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published var state: TranscriptionState = .idle
    @Published var progress: Double = 0
    @Published var downloadStatusText: String = ""
    @Published var transcriptionLanguage: TranscriptionLanguage = .english
    @Published var isModelLoaded: Bool = false

    private var whisperKit: WhisperKit?
    private var transcriptionTask: Task<Void, Never>?
    private var progressTimer: Timer?

    // Timeout settings
    private let modelLoadTimeout: TimeInterval = 600 // 10 minutes
    private let transcriptionTimeout: TimeInterval = 600 // 10 minutes

    // Explicitly use base.en model (~150MB) - prevents WhisperKit from
    // auto-selecting large-v3 (626MB) on high-RAM devices like iPad
    private let preferredModel = "base.en"

    /// Path to bundled model in app bundle (nil if not bundled)
    private var bundledModelPath: String? {
        if let modelsDir = Bundle.main.resourceURL?.appendingPathComponent("WhisperKitModels"),
           FileManager.default.fileExists(atPath: modelsDir.path) {
            return modelsDir.path
        }
        return nil
    }

    private init() {
        AppLogger.debug("TranscriptionService initialized (English-only)", category: .transcription)
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

    /// Load model with progress tracking
    func loadModel() async throws {
        guard !isModelLoaded else { return }

        state = .downloading
        progress = 0
        downloadStatusText = "Preparing AI model..."

        do {
            try await loadModelInternal()
        } catch {
            // If loading fails (e.g. corrupted cache), clear cache and retry once
            AppLogger.warning("Model load failed, clearing cache and retrying: \(error)", category: .transcription)
            try? clearModelCache()
            do {
                try await loadModelInternal()
            } catch is TimeoutError {
                stopProgressSimulation()
                state = .failed
                downloadStatusText = "Download timed out"
                throw TranscriptionError.modelLoadFailed("Model loading timed out. Please check your network connection and try again.")
            } catch {
                stopProgressSimulation()
                state = .failed
                downloadStatusText = "Download failed"
                throw TranscriptionError.modelLoadFailed(error.localizedDescription)
            }
        }
    }

    private func loadModelInternal() async throws {
        AppLogger.debug("Loading WhisperKit model (\(preferredModel))", category: .transcription)

        if let bundledPath = bundledModelPath {
            downloadStatusText = "Loading bundled model..."
            AppLogger.debug("Using bundled model at: \(bundledPath)", category: .transcription)
            whisperKit = try await WhisperKit(WhisperKitConfig(modelFolder: bundledPath))
        } else {
            downloadStatusText = "Downloading AI model (~150 MB)..."
            AppLogger.debug("Downloading model: \(preferredModel)", category: .transcription)

            startProgressSimulation()

            let config = WhisperKitConfig(model: preferredModel)
            whisperKit = try await withTimeout(seconds: modelLoadTimeout) {
                try await WhisperKit(config)
            }

            stopProgressSimulation()
        }

        isModelLoaded = true
        state = .idle
        progress = 1.0
        downloadStatusText = "AI model ready"
        AppLogger.info("WhisperKit model loading completed (\(preferredModel))", category: .transcription)
    }

    /// Simulate download progress (since WhisperKit doesn't expose it)
    private func startProgressSimulation() {
        progress = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state == .downloading else { return }
                // Slow logarithmic progress that approaches but never reaches 0.95
                if self.progress < 0.9 {
                    self.progress += (0.92 - self.progress) * 0.03
                }
            }
        }
    }

    private func stopProgressSimulation() {
        progressTimer?.invalidate()
        progressTimer = nil
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

    /// Execute transcription
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
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

        // Check audio duration (reject recordings shorter than 1 second)
        do {
            let asset = AVURLAsset(url: audioURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds
            if durationSeconds.isNaN || durationSeconds < 1.0 {
                AppLogger.warning("Audio too short: \(durationSeconds)s", category: .transcription)
                throw TranscriptionError.audioFileTooShort
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            AppLogger.warning("Could not check audio duration: \(error)", category: .transcription)
            // Continue anyway - WhisperKit will handle invalid files
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
        decodeOptions.language = "en"
        decodeOptions.usePrefillPrompt = true
        decodeOptions.detectLanguage = false

        do {
            AppLogger.debug("Starting transcription (\(preferredModel))", category: .transcription)
            return try await runTranscription(whisperKit: currentKit, audioURL: audioURL, decodeOptions: decodeOptions, timeout: transcriptionTimeout)
        } catch is TimeoutError {
            state = .failed
            AppLogger.error("Transcription timed out after \(transcriptionTimeout) seconds", category: .transcription)
            throw TranscriptionError.transcriptionTimedOut
        } catch {
            state = .failed
            throw error
        }
    }

    /// Run transcription and return result
    private func runTranscription(whisperKit: WhisperKit, audioURL: URL, decodeOptions: DecodingOptions, timeout: TimeInterval) async throws -> TranscriptionResult {
        let whisperResults = try await withTimeout(seconds: timeout) {
            try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: decodeOptions
            )
        }

        guard let whisperResult = whisperResults.first else {
            AppLogger.error("WhisperKit returned no results", category: .transcription)
            throw TranscriptionError.emptyTranscriptionResult
        }

        typealias LectureTranscriptionResult = TranscriptionResult
        typealias LectureTranscriptionSegment = LectureTranscriptionResult.TranscriptionSegment

        let segments = whisperResult.segments.map { segment in
            LectureTranscriptionSegment(
                startTime: Double(segment.start),
                endTime: Double(segment.end),
                text: Self.stripWhisperTokens(segment.text)
            )
        }

        let fullText = Self.stripWhisperTokens(whisperResult.text)

        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AppLogger.warning("Transcription produced empty text (audio may be silent or too short)", category: .transcription)
            throw TranscriptionError.emptyTranscriptionResult
        }

        state = .completed
        progress = 1.0

        return LectureTranscriptionResult(
            text: fullText,
            segments: segments,
            language: whisperResult.language,
            processingTime: 0.0
        )
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
        }
    }
}
