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

/// Recording service
@MainActor
class RecordingService: NSObject, ObservableObject {
    static let shared = RecordingService()
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingStartTime: Date?
    @Published var pausedDuration: TimeInterval = 0 // Cumulative paused time
    @Published var audioLevel: Float = 0
    @Published var audioLevelHistory: [Float] = Array(repeating: 0, count: 30)

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var meteringTimer: Timer?
    private var backgroundTaskTimer: Timer?
    private var recordingURL: URL?
    private var liveActivity: Activity<LecsyWidgetAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var currentLectureTitle: String = "New Recording"
    private var pauseStartTime: Date? // Pause start time
    
    // Support up to 100 minutes (6000 seconds) of recording
    private let maxRecordingDuration: TimeInterval = 6000 // 100 minutes
    
    private var isAudioSessionPrepared = false

    private override init() {
        super.init()
    }

    /// Pre-configure audio session so recording starts instantly
    func prepareAudioSession() {
        guard !isAudioSessionPrepared else { return }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
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
        
        // Check disk space (approximately 50-100MB needed for 100 minutes of recording)
        let requiredSpace: Int64 = 100 * 1024 * 1024 // 100MB
        if let availableSpace = getAvailableDiskSpace(), availableSpace < requiredSpace {
            AppLogger.debug("Insufficient disk space: Available \(availableSpace / 1024 / 1024)MB, Required \(requiredSpace / 1024 / 1024)MB", category: .recording)
            throw RecordingError.insufficientStorage
        }
        
        // Ensure audio session is ready (should already be prepared)
        if !isAudioSessionPrepared {
            prepareAudioSession()
        }

        // Re-activate if needed (e.g., after previous deactivation on stop)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
            }
        } catch {
            AppLogger.error("Audio session activation error: \(error)", category: .recording)
            throw RecordingError.recordingFailed
        }
        
        // Start background task
        setupBackgroundTask()
        
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
            AVEncoderBitRateKey: 64000 // 64kbps (approximately 50MB for 100 minutes)
        ]
        
        // Start recording
        AppLogger.debug("Creating AVAudioRecorder", category: .recording)
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            let recordingStarted = audioRecorder?.record() ?? false
            AppLogger.debug("Recording started: \(recordingStarted)", category: .recording)
            
            if !recordingStarted {
                AppLogger.error("Failed to start recording", category: .recording)
                throw RecordingError.recordingFailed
            }
        } catch {
            AppLogger.error("AVAudioRecorder creation/start error: \(error)", category: .recording)
            throw RecordingError.recordingFailed
        }
        
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        recordingDuration = 0
        pausedDuration = 0
        pauseStartTime = nil
        currentLectureTitle = lectureTitle
        
        AppLogger.debug("Updated recording state: isRecording = \(isRecording), isPaused = \(isPaused)", category: .recording)
        
        // Start Live Activity
        startLiveActivity()
        
        // Start timer (update duration every 1 second)
        var liveActivityCounter = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let startTime = self.recordingStartTime else {
                timer.invalidate()
                return
            }

            // Update time only if not paused
            if !self.isPaused {
                let totalElapsed = Date().timeIntervalSince(startTime)
                self.recordingDuration = totalElapsed - self.pausedDuration
            }

            // Check max recording time
            if self.recordingDuration >= self.maxRecordingDuration {
                _ = self.stopRecording()
                return
            }

            // Check if recording is continuing (e.g., on lock screen)
            if !self.isPaused, let recorder = self.audioRecorder, !recorder.isRecording {
                recorder.record()
            }

            // Update Live Activity every 5 seconds (battery optimization)
            liveActivityCounter += 1
            if liveActivityCounter >= 5 {
                liveActivityCounter = 0
                self.updateLiveActivity()
            }
        }
        
        // Add timer to RunLoop so it works in background too
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        // Start metering timer (12Hz for smooth waveform)
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording, !self.isPaused else { return }
            self.audioRecorder?.updateMeters()
            let db = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            let normalized = max(0, min(1, (db + 50) / 50))
            self.audioLevel = normalized
            // Ring buffer: cap at 60 entries for memory efficiency
            if self.audioLevelHistory.count >= 60 {
                self.audioLevelHistory.removeFirst(self.audioLevelHistory.count - 29)
            }
            self.audioLevelHistory.append(normalized)
        }
        if let meteringTimer = meteringTimer {
            RunLoop.current.add(meteringTimer, forMode: .common)
        }

        // Periodic background task renewal (every 30 seconds)
        setupBackgroundTaskRenewal()

        AppLogger.debug("Timer started", category: .recording)
    }
    
    /// Pause recording
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        
        AppLogger.debug("Pausing recording", category: .recording)
        audioRecorder?.pause()
        isPaused = true
        pauseStartTime = Date()
        
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
        
        audioRecorder?.record()
        isPaused = false
        
        // Update Live Activity (reflect resume state)
        updateLiveActivity()
    }
    
    /// Stop recording
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
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
        
        // End Live Activity
        endLiveActivity()
        
        // End background task
        endBackgroundTask()
        
        let url = recordingURL
        recordingURL = nil
        recordingStartTime = nil
        pausedDuration = 0

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        isAudioSessionPrepared = false

        // Validate recording file
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
    
    /// Periodic background task renewal (for long recording)
    private func setupBackgroundTaskRenewal() {
        // Renew background task every 30 seconds
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else {
                return
            }
            
            // End existing task
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
            }
            
            // Start new task
            self.setupBackgroundTask()
            
            AppLogger.debug("Background task renewed", category: .recording)
        }
    }
    
    // MARK: - Live Activities
    
    /// Start Live Activity
    private func startLiveActivity() {
        // Check if ActivityKit is available
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.warning("Live Activities are not enabled", category: .recording)
            return
        }
        
        let attributes = LecsyWidgetAttributes(lectureTitle: currentLectureTitle)
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: 0,
            isRecording: true
        )
        
        do {
            liveActivity = try Activity<LecsyWidgetAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
        } catch {
            AppLogger.error("Failed to start Live Activity: \(error)", category: .recording)
        }
    }
    
    /// Update Live Activity
    private func updateLiveActivity() {
        guard let liveActivity = liveActivity else { return }
        
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: recordingDuration,
            isRecording: isRecording && !isPaused
        )
        
        // Update asynchronously (execute on main thread)
        // Update every 1 second to smoothly move lock screen stopwatch
        Task { @MainActor in
            do {
                await liveActivity.update(
                    using: contentState,
                    alertConfiguration: nil
                )
            } catch {
                // If errors occur frequently, reduce update frequency
                AppLogger.warning("Live Activity update error: \(error)", category: .recording)
            }
        }
    }
    
    /// End Live Activity
    private func endLiveActivity() {
        guard let liveActivity = liveActivity else { return }
        
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: recordingDuration,
            isRecording: false
        )
        
        Task {
            await liveActivity.end(using: contentState, dismissalPolicy: .immediate)
        }
        
        self.liveActivity = nil
    }
    
    // MARK: - Background Task
    
    /// Start background task
    private func setupBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    /// End background task
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
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
                return "Insufficient storage space. At least 100MB of free space is required."
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                isRecording = false
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            AppLogger.error("Recording encode error: \(error?.localizedDescription ?? "Unknown error")", category: .recording)
            isRecording = false
            timer?.invalidate()
            timer = nil
            meteringTimer?.invalidate()
            meteringTimer = nil
            backgroundTaskTimer?.invalidate()
            backgroundTaskTimer = nil
            endLiveActivity()
            endBackgroundTask()
        }
    }
    
    nonisolated func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        Task { @MainActor in
            AppLogger.debug("Recording interrupted (e.g., phone call)", category: .recording)
            // Continue recording on interruption (iOS handles automatically)
        }
    }
    
    nonisolated func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        Task { @MainActor in
            AppLogger.debug("Recording interruption ended", category: .recording)
            // Resume recording if needed
            if isRecording {
                audioRecorder?.record()
            }
        }
    }
}
