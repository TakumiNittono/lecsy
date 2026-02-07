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
    @Published var transcriptionLanguage: TranscriptionLanguage = .english
    @Published var isModelLoaded: Bool = false
    @Published var modelDownloadProgress: Double = 0
    
    private var whisperKit: WhisperKit?
    private var transcriptionTask: Task<Void, Never>?
    private var currentLanguageCode: String? // Currently set language code
    
    // Timeout settings
    private let modelLoadTimeout: TimeInterval = 300 // 5 minutes for model loading
    private let transcriptionTimeout: TimeInterval = 300 // 5 minutes for transcription
    
    private init() {
        // English-only: Always use English
        transcriptionLanguage = .english
        currentLanguageCode = "en"
        UserDefaults.standard.set(TranscriptionLanguage.english.rawValue, forKey: "transcriptionLanguage")
        print("🔵 TranscriptionLanguage: English-only mode - Always using English")
    }
    
    /// Change and save language setting
    func setLanguage(_ language: TranscriptionLanguage) {
        transcriptionLanguage = language
        currentLanguageCode = language.whisperLanguage
        UserDefaults.standard.set(language.rawValue, forKey: "transcriptionLanguage")
        
        // Reset whisperKit to nil as model may need to be reloaded when language changes
        whisperKit = nil
        isModelLoaded = false
        
        print("🔵 Language setting changed: \(language.displayName) (\(language.rawValue))")
        if let langCode = currentLanguageCode {
            print("🔵 Language code: \(langCode)")
        } else {
            print("🔵 Auto-detect mode")
        }
    }
    
    /// Check if model is downloaded
    func isModelDownloaded() -> Bool {
        // Check WhisperKit model cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = cacheDir.appendingPathComponent("WhisperKit")
        let modelPath = modelDir.appendingPathComponent("openai_whisper-coreml-base")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Load model with timeout
    func loadModel() async throws {
        guard !isModelLoaded else { return }
        
        state = .downloading
        progress = 0
        
        do {
            // Initialize WhisperKit (automatically downloads model)
            // Use base model (approximately 500MB, fast)
            print("🔵 Loading WhisperKit model: Language setting = \(transcriptionLanguage.displayName)")
            print("🔵 Model load timeout: \(modelLoadTimeout) seconds")
            
            // Initialize WhisperKit with timeout
            whisperKit = try await withTimeout(seconds: modelLoadTimeout) {
                try await WhisperKit()
            }
            
            isModelLoaded = true
            state = .idle
            progress = 1.0
            print("🔵 WhisperKit model loading completed")
        } catch is TimeoutError {
            state = .failed
            print("❌ Model loading timed out after \(modelLoadTimeout) seconds")
            throw TranscriptionError.modelLoadFailed("Model loading timed out. Please check your network connection and try again.")
        } catch {
            state = .failed
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
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
    
    /// Execute transcription with timeout
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Automatically load model if not loaded
        if whisperKit == nil {
            try await loadModel()
        }
        
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        state = .processing
        progress = 0
        
        do {
            // Log configured language
            print("🔵 Starting transcription: Language setting = \(transcriptionLanguage.displayName) (\(transcriptionLanguage.rawValue))")
            print("🔵 Transcription timeout: \(transcriptionTimeout) seconds")
            
            // Specify language in DecodingOptions
            var decodeOptions = DecodingOptions()
            
            // English-only: Always process as English
            if let languageCode = currentLanguageCode {
                decodeOptions.language = languageCode
                decodeOptions.usePrefillPrompt = true // Required to force language specification
                decodeOptions.detectLanguage = false // Disable language detection and process as English
                print("🔵 English-only: Forcing language to English: \(languageCode)")
            } else {
                // Fallback (should not normally occur)
                decodeOptions.language = "en"
                decodeOptions.usePrefillPrompt = true
                decodeOptions.detectLanguage = false
                print("🔵 English-only: Fallback setting to English")
            }
            
            // Execute transcription with timeout (WhisperKit processes audio file directly)
            // WhisperKit's transcribe method returns [TranscriptionResult]
            let whisperResults = try await withTimeout(seconds: transcriptionTimeout) {
                try await whisperKit.transcribe(
                    audioPath: audioURL.path,
                    decodeOptions: decodeOptions
                )
            }
            
            print("🔵 Language detected by WhisperKit: \(whisperResults.first?.language ?? "Unknown")")
            
            // Check if configured language matches detected language
            if let detectedLanguage = whisperResults.first?.language,
               let languageCode = currentLanguageCode,
               detectedLanguage != languageCode {
                print("⚠️ Warning: Configured language(\(languageCode)) does not match detected language(\(detectedLanguage))")
            }
            
            // Get first result from array
            guard let whisperResult = whisperResults.first else {
                throw TranscriptionError.transcriptionFailed
            }
            
            // Convert result (from WhisperKit's TranscriptionResult to custom TranscriptionResult)
            // Use type alias to clarify namespace
            typealias LectureTranscriptionResult = TranscriptionResult
            typealias LectureTranscriptionSegment = LectureTranscriptionResult.TranscriptionSegment
            
            // Convert WhisperKit's segments (Float start/end) to Double
            let segments = whisperResult.segments.map { segment in
                LectureTranscriptionSegment(
                    startTime: Double(segment.start),
                    endTime: Double(segment.end),
                    text: segment.text
                )
            }
            
            let fullText = whisperResult.text
            
            state = .completed
            progress = 1.0
            
            // Use default value as processingTime property may not exist
            // WhisperKit's TranscriptionResult may not have processingTime property
            let processingTime: TimeInterval = 0.0
            
            return LectureTranscriptionResult(
                text: fullText,
                segments: segments,
                language: whisperResult.language,
                processingTime: processingTime
            )
        } catch is TimeoutError {
            state = .failed
            print("❌ Transcription timed out after \(transcriptionTimeout) seconds")
            throw TranscriptionError.transcriptionTimedOut
        } catch {
            state = .failed
            throw error
        }
    }
    
    /// Cancel transcription
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        state = .idle
        progress = 0
    }
    
    /// Delete model
    func deleteModel() throws {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = cacheDir.appendingPathComponent("WhisperKit")
        
        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
        }
        
        whisperKit = nil
        isModelLoaded = false
    }
    
    /// Get model size (in bytes)
    var modelSize: Int64 {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = cacheDir.appendingPathComponent("WhisperKit")
        
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: modelDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
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
    case transcriptionTimedOut
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded"
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .audioLoadFailed:
            return "Failed to load audio file"
        case .transcriptionFailed:
            return "Transcription failed"
        case .transcriptionTimedOut:
            return "Transcription timed out. The audio may be too long or the device is too slow. Please try again with a shorter recording."
        }
    }
}
