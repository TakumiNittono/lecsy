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
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var backgroundTaskTimer: Timer?
    private var recordingURL: URL?
    private var liveActivity: Activity<LecsyWidgetAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var currentLectureTitle: String = "New Recording"
    private var pauseStartTime: Date? // Pause start time
    
    // Support up to 100 minutes (6000 seconds) of recording
    private let maxRecordingDuration: TimeInterval = 6000 // 100 minutes
    
    private override init() {
        super.init()
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
        print("🔴 RecordingService.startRecording() called")
        
        guard !isRecording else {
            print("🔴 Already recording")
            return
        }
        
        // Check microphone permission
        let hasPermission = AVAudioSession.sharedInstance().recordPermission
        print("🔴 Microphone permission status: \(hasPermission.rawValue)")
        guard hasPermission == .granted else {
            print("🔴 No microphone permission")
            throw RecordingError.permissionDenied
        }
        
        // Check disk space (approximately 50-100MB needed for 100 minutes of recording)
        let requiredSpace: Int64 = 100 * 1024 * 1024 // 100MB
        if let availableSpace = getAvailableDiskSpace(), availableSpace < requiredSpace {
            print("🔴 Insufficient disk space: Available \(availableSpace / 1024 / 1024)MB, Required \(requiredSpace / 1024 / 1024)MB")
            throw RecordingError.insufficientStorage
        }
        
        // Configure audio session (background recording support)
        print("🔴 Setting up audio session")
        let audioSession = AVAudioSession.sharedInstance()
        
        // Wait a bit for permission to be reflected (if permission was just requested)
        if AVAudioSession.sharedInstance().recordPermission == .granted {
            // Wait a bit before setting session
            try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        }
        
        do {
            // Deactivate existing session (to avoid errors)
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Optimized settings for background recording
            // Removed .allowBluetoothA2DP (not needed for recording, may cause errors)
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            
            // Enable background recording
            try audioSession.setActive(true, options: [])
            
            // Check if background recording is enabled
            if !audioSession.isOtherAudioPlaying {
                print("🔴 Audio session setup successful (background recording enabled)")
            } else {
                print("⚠️ Other audio is playing")
            }
        } catch {
            print("🔴 Audio session setup error: \(error)")
            throw RecordingError.recordingFailed
        }
        
        // Start background task
        setupBackgroundTask()
        
        // Recording file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            print("🔴 Failed to create recording file URL")
            throw RecordingError.fileCreationFailed
        }
        
        print("🔴 Recording file URL: \(url)")
        
        // Recording settings (optimized for long recording: balance quality and file size)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue, // Changed to medium for long recording
            AVEncoderBitRateKey: 64000 // 64kbps (approximately 50MB for 100 minutes)
        ]
        
        // Start recording
        print("🔴 Creating AVAudioRecorder")
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            
            let recordingStarted = audioRecorder?.record() ?? false
            print("🔴 Recording started: \(recordingStarted)")
            
            if !recordingStarted {
                print("🔴 Failed to start recording")
                throw RecordingError.recordingFailed
            }
        } catch {
            print("🔴 AVAudioRecorder creation/start error: \(error)")
            throw RecordingError.recordingFailed
        }
        
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        recordingDuration = 0
        pausedDuration = 0
        pauseStartTime = nil
        currentLectureTitle = lectureTitle
        
        print("🔴 Updated recording state: isRecording = \(isRecording), isPaused = \(isPaused)")
        
        // Start Live Activity
        startLiveActivity()
        
        // Start timer (update every 1 second, Live Activity also updates every 1 second)
        // Add to RunLoop so it works in background too
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
            
            // Check max recording time (actual recording time excluding pause time)
            if self.recordingDuration >= self.maxRecordingDuration {
                print("🔴 Reached max recording time (100 minutes)")
                _ = self.stopRecording()
                return
            }
            
            // Check if recording is continuing (only when not paused, e.g., on lock screen)
            if !self.isPaused, let recorder = self.audioRecorder, !recorder.isRecording {
                print("⚠️ Recording has stopped. Attempting to resume...")
                // Resume recording
                recorder.record()
            }
            
            // Update Live Activity every 1 second (to smoothly move lock screen stopwatch)
            self.updateLiveActivity()
        }
        
        // Add timer to RunLoop so it works in background too
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        // Periodic background task renewal (every 30 seconds)
        setupBackgroundTaskRenewal()
        
        print("🔴 Timer started")
    }
    
    /// Pause recording
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        
        print("⏸️ Pausing recording")
        audioRecorder?.pause()
        isPaused = true
        pauseStartTime = Date()
        
        // Update Live Activity (reflect pause state)
        updateLiveActivity()
    }
    
    /// Resume recording
    func resumeRecording() {
        guard isRecording, isPaused else { return }
        
        print("▶️ Resuming recording")
        
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
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        
        isRecording = false
        isPaused = false
        pauseStartTime = nil
        
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
            print("🔴 Disk space retrieval error: \(error)")
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
            
            print("🔴 Background task renewed")
        }
    }
    
    // MARK: - Live Activities
    
    /// Start Live Activity
    private func startLiveActivity() {
        // Check if ActivityKit is available
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities are not enabled")
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
            print("❌ Failed to start Live Activity: \(error)")
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
                print("⚠️ Live Activity update error: \(error)")
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
            print("🔴 Recording encode error: \(error?.localizedDescription ?? "Unknown error")")
            isRecording = false
            timer?.invalidate()
            timer = nil
            backgroundTaskTimer?.invalidate()
            backgroundTaskTimer = nil
            endLiveActivity()
            endBackgroundTask()
        }
    }
    
    nonisolated func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        Task { @MainActor in
            print("🔴 Recording interrupted (e.g., phone call)")
            // Continue recording on interruption (iOS handles automatically)
        }
    }
    
    nonisolated func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        Task { @MainActor in
            print("🔴 Recording interruption ended")
            // Resume recording if needed
            if isRecording {
                audioRecorder?.record()
            }
        }
    }
}
