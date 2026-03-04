//
//  RecordView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import AVFoundation
import UIKit

struct RecordView: View {
    @StateObject private var recordingService = RecordingService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared
    @AppStorage("lecsy.hasAcceptedAIConsent") private var hasAcceptedAIConsent = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showRecordingErrorAlert = false
    @State private var recordingError: UserFacingError?
    @State private var showTranscriptionErrorAlert = false
    @State private var transcriptionError: UserFacingError?
    @State private var showTitleSheet = false
    @State private var showAIConsentSheet = false
    @State private var pendingAudioURL: URL?
    @State private var pendingDuration: TimeInterval = 0
    @State private var lowAudioSeconds: Int = 0
    @State private var showLowAudioWarning = false
    @State private var recordingDotOpacity: Double = 1.0
    @State private var pendingBookmarks: [LectureBookmark] = []
    @State private var showBookmarkToast = false
    @State private var lastFailedLectureId: UUID?

    var body: some View {
        ZStack {
            // Main recording UI
            VStack(spacing: 24) {
                Spacer()

                // Timer display
                Text(formatDuration(recordingService.recordingDuration))
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(recordingService.isRecording ? .primary : .secondary.opacity(0.5))
                    .kerning(1.5)
                    .accessibilityLabel("Recording duration: \(formatDuration(recordingService.recordingDuration))")

                // Audio waveform
                if recordingService.isRecording {
                    AudioWaveformView(levels: recordingService.audioLevelHistory)
                        .transition(.opacity)
                }

                // Recording status indicator
                if recordingService.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(recordingService.isPaused ? 0.4 : recordingDotOpacity)

                        Text(recordingService.isPaused ? "Paused" : "Recording")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(recordingService.isPaused ? .orange : .red)
                            .textCase(.uppercase)
                            .kerning(1)

                        Text("|")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))

                        Text(estimatedFileSize())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            recordingDotOpacity = 0.2
                        }
                    }
                    .onDisappear {
                        recordingDotOpacity = 1.0
                    }
                }

                // Low audio warning
                if showLowAudioWarning && recordingService.isRecording && !recordingService.isPaused {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Audio level is low — move closer to the speaker")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .transition(.opacity)
                }

                // Bookmark toast
                if showBookmarkToast {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                        Text("Bookmarked!")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.9))
                    .cornerRadius(16)
                    .transition(.opacity.combined(with: .scale))
                }

                // Record button, pause button, bookmark button
                HStack(spacing: isIPad ? 32 : 24) {
                    // Pause/Resume button (only shown when recording)
                    if recordingService.isRecording {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if recordingService.isPaused {
                                recordingService.resumeRecording()
                            } else {
                                recordingService.pauseRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.8))
                                    .frame(width: isIPad ? 72 : 56, height: isIPad ? 72 : 56)

                                Image(systemName: recordingService.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: isIPad ? 26 : 20))
                                    .foregroundColor(.white)
                            }
                        }
                        .accessibilityLabel(recordingService.isPaused ? "Resume recording" : "Pause recording")
                    }

                    // Record start/stop button
                    Button(action: {
                        if recordingService.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(recordingService.isRecording ? Color.red.opacity(0.8) : Color.blue)
                                .frame(width: isIPad ? 96 : 72, height: isIPad ? 96 : 72)
                                .shadow(color: recordingService.isRecording ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 8, y: 4)

                            Image(systemName: recordingService.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: isIPad ? 34 : 26))
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel(recordingService.isRecording ? "Stop recording" : "Start recording")

                    // Bookmark button (only shown when recording)
                    if recordingService.isRecording {
                        Button(action: addBookmark) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.8))
                                    .frame(width: isIPad ? 72 : 56, height: isIPad ? 72 : 56)

                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: isIPad ? 26 : 20))
                                    .foregroundColor(.white)
                            }
                        }
                        .accessibilityLabel("Add bookmark")
                    }
                }

                // Bookmark count
                if recordingService.isRecording && !pendingBookmarks.isEmpty {
                    Text("\(pendingBookmarks.count) bookmark\(pendingBookmarks.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Idle hint
                if !recordingService.isRecording {
                    Text("Tap to start recording")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .kerning(0.5)
                }

                Spacer()
            }
            .padding()

        }
        .alert(recordingError?.title ?? "Error", isPresented: $showRecordingErrorAlert) {
            if recordingError?.actionLabel == "Open Settings" {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(recordingError?.message ?? "")
        }
        .alert(transcriptionError?.title ?? "Error", isPresented: $showTranscriptionErrorAlert) {
            if lastFailedLectureId != nil {
                Button("Retry") {
                    retryTranscription()
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(transcriptionError?.message ?? "")
        }
        .sheet(isPresented: $showAIConsentSheet) {
            AIConsentView {
                hasAcceptedAIConsent = true
                showAIConsentSheet = false
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: recordingService.recordingDuration) { _, _ in
            guard recordingService.isRecording, !recordingService.isPaused else {
                lowAudioSeconds = 0
                showLowAudioWarning = false
                return
            }
            if recordingService.audioLevel < 0.05 {
                lowAudioSeconds += 1
            } else {
                lowAudioSeconds = 0
            }
            withAnimation {
                showLowAudioWarning = lowAudioSeconds >= 5
            }
        }
        .onChange(of: recordingService.isRecording) { _, isRecording in
            if !isRecording {
                lowAudioSeconds = 0
                showLowAudioWarning = false
            }
        }
        .sheet(isPresented: $showTitleSheet) {
            TitleInputSheet(defaultTitle: defaultRecordingTitle()) { title, courseName in
                saveLecture(title: title, courseName: courseName)
            }
        }
        .onAppear {
            // Pre-configure audio session so record starts instantly
            recordingService.prepareAudioSession()
        }
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Recording Actions

    private func addBookmark() {
        let bookmark = LectureBookmark(timestamp: recordingService.recordingDuration)
        pendingBookmarks.append(bookmark)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { showBookmarkToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { showBookmarkToast = false }
        }
    }

    private func retryTranscription() {
        guard let lectureId = lastFailedLectureId else { return }
        guard let lecture = LectureStore.shared.lectures.first(where: { $0.id == lectureId }) else { return }

        lastFailedLectureId = nil
        Task {
            await startTranscription(for: lecture)
        }
    }

    private func startRecording() {
        Task { @MainActor in
            // Check AI consent
            if !hasAcceptedAIConsent {
                showAIConsentSheet = true
                return
            }

            // Permission check
            let permissionStatus = AVAudioSession.sharedInstance().recordPermission
            if permissionStatus == .undetermined {
                let granted = await recordingService.requestMicrophonePermission()
                if !granted {
                    recordingError = ErrorMessages.forRecording(RecordingService.RecordingError.permissionDenied)
                    showRecordingErrorAlert = true
                    return
                }
            } else if permissionStatus != .granted {
                recordingError = ErrorMessages.forRecording(RecordingService.RecordingError.permissionDenied)
                showRecordingErrorAlert = true
                return
            }

            do {
                try await recordingService.startRecording()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                pendingBookmarks = []
            } catch {
                recordingError = ErrorMessages.forRecording(error)
                showRecordingErrorAlert = true
            }
        }
    }

    private func stopRecording() {
        pendingDuration = recordingService.recordingDuration
        guard let audioURL = recordingService.stopRecording() else { return }
        pendingAudioURL = audioURL
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showTitleSheet = true
    }

    private func saveLecture(title: String, courseName: String?) {
        guard let audioURL = pendingAudioURL else { return }

        let lecture = Lecture(
            title: title,
            createdAt: Date(),
            duration: pendingDuration,
            audioPath: audioURL,
            transcriptStatus: .notStarted,
            language: transcriptionService.transcriptionLanguage,
            bookmarks: pendingBookmarks,
            courseName: courseName
        )

        let store = LectureStore.shared
        store.addLecture(lecture)

        pendingAudioURL = nil
        pendingDuration = 0
        pendingBookmarks = []

        NotificationCenter.default.post(name: .lectureRecordingCompleted, object: nil)

        Task {
            await startTranscription(for: lecture)
        }
    }

    private func defaultRecordingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return "Lecture \(formatter.string(from: Date()))"
    }

    private func startTranscription(for lecture: Lecture) async {
        guard let audioURL = lecture.audioPath else { return }

        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        LectureStore.shared.updateLecture(updatedLecture)

        do {
            let result = try await transcriptionService.transcribe(audioURL: audioURL)

            updatedLecture.transcriptText = result.text
            updatedLecture.transcriptSegments = result.segments
            updatedLecture.transcriptStatus = .completed
            updatedLecture.language = transcriptionService.transcriptionLanguage
            LectureStore.shared.updateLecture(updatedLecture)
        } catch {
            updatedLecture.transcriptStatus = .failed
            LectureStore.shared.updateLecture(updatedLecture)
            AppLogger.error("Transcription failed: \(error)", category: .recording)

            await MainActor.run {
                lastFailedLectureId = lecture.id
                transcriptionError = ErrorMessages.forTranscription(error)
                showTranscriptionErrorAlert = true
            }
        }
    }

    // MARK: - Helpers

    private func estimatedFileSize() -> String {
        // M4A at 64kbps mono
        let bytesPerSecond = 64_000.0 / 8.0
        let totalBytes = bytesPerSecond * recordingService.recordingDuration
        if totalBytes < 1_000_000 {
            return String(format: "%.0f KB", totalBytes / 1_000)
        } else {
            return String(format: "%.1f MB", totalBytes / 1_000_000)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    RecordView()
}
