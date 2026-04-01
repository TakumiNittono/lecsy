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
    @State private var currentLanguageDisplay: String = TranscriptionService.shared.transcriptionLanguage.displayName
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
    @State private var showLanguagePicker = false
    @State private var showRecoverySheet = false
    @State private var recoveredURL: URL?
    @State private var recoveredDuration: TimeInterval = 0
    @State private var recoveredTitle: String = ""
    @State private var hasCheckedRecovery = false

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()
                timerDisplay
                waveformDisplay
                statusIndicator
                lowAudioWarning
                bookmarkToast
                controlButtons
                bookmarkCount
                idleHint
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
            if recordingService.audioLevel < 0.08 {
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
        .onReceive(NotificationCenter.default.publisher(for: TranscriptionService.languageDidChangeNotification)) { _ in
            currentLanguageDisplay = TranscriptionService.shared.transcriptionLanguage.displayName
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(
                selectedLanguage: transcriptionService.transcriptionLanguage,
                onSelect: { language in
                    transcriptionService.setLanguage(language)
                    currentLanguageDisplay = language.displayName
                    showLanguagePicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTitleSheet) {
            TitleInputSheet(defaultTitle: defaultRecordingTitle()) { title, courseName in
                saveLecture(title: title, courseName: courseName)
            }
        }
        .sheet(isPresented: $showRecoverySheet) {
            RecoverySheet(
                duration: recoveredDuration,
                defaultTitle: recoveredTitle
            ) { title, courseName in
                saveRecoveredLecture(title: title, courseName: courseName)
            } onDiscard: {
                discardRecoveredRecording()
            }
        }
        .onAppear {
            // Pre-configure audio session so record starts instantly
            recordingService.prepareAudioSession()

            // Check for orphaned recording from a previous crash/kill
            if !hasCheckedRecovery {
                hasCheckedRecovery = true
                Task {
                    if let recovered = await recordingService.recoverOrphanedRecording() {
                        recoveredURL = recovered.url
                        recoveredDuration = recovered.duration
                        recoveredTitle = recovered.title
                        showRecoverySheet = true
                    }
                }
            }
        }
        .onChange(of: recordingService.unexpectedlySavedRecording) { _, saved in
            // Handle recording that was auto-saved due to unexpected interruption
            guard let saved = saved else { return }
            recoveredURL = saved.url
            recoveredDuration = saved.duration
            recoveredTitle = saved.title
            recordingService.unexpectedlySavedRecording = nil
            showRecoverySheet = true
        }
    }

    // MARK: - Subviews (broken out to help Swift type-checker)

    private var timerDisplay: some View {
        Text(formatDuration(recordingService.recordingDuration))
            .font(.system(size: 54, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(recordingService.isRecording ? .primary : .secondary.opacity(0.5))
            .kerning(1.5)
            .accessibilityLabel("Recording duration: \(formatDuration(recordingService.recordingDuration))")
    }

    @ViewBuilder
    private var waveformDisplay: some View {
        if recordingService.isRecording {
            AudioWaveformView(levels: recordingService.audioLevelHistory)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
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

                Text(estimatedFileSize(recordingService.recordingDuration))
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
    }

    @ViewBuilder
    private var lowAudioWarning: some View {
        if showLowAudioWarning && recordingService.isRecording && !recordingService.isPaused {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("Audio level is low — move closer to the speaker")
                    .font(.caption)
            }
            .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var bookmarkToast: some View {
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
    }

    private var controlButtons: some View {
        HStack(spacing: isIPad ? 32 : 24) {
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
    }

    @ViewBuilder
    private var bookmarkCount: some View {
        if recordingService.isRecording && !pendingBookmarks.isEmpty {
            Text("\(pendingBookmarks.count) bookmark\(pendingBookmarks.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var idleHint: some View {
        if !recordingService.isRecording {
            VStack(spacing: 8) {
                Text("Tap to start recording")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
                    .kerning(0.5)

                Button {
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption2)
                        Text(currentLanguageDisplay)
                            .font(.system(.caption2, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(.blue.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
                }

                if !transcriptionService.isModelLoaded {
                    HStack(spacing: 5) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("AI preparing...")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary.opacity(0.4))
                }
            }
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
        guard let audioURL = recordingService.stopRecording() else {
            recordingError = UserFacingError(
                title: "Recording Not Saved",
                message: "The recording could not be saved. Please try again."
            )
            showRecordingErrorAlert = true
            return
        }
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

    private func saveRecoveredLecture(title: String, courseName: String?) {
        guard let audioURL = recoveredURL else { return }

        let lecture = Lecture(
            title: title,
            createdAt: Date(),
            duration: recoveredDuration,
            audioPath: audioURL,
            transcriptStatus: .notStarted,
            language: transcriptionService.transcriptionLanguage,
            bookmarks: [],
            courseName: courseName
        )

        LectureStore.shared.addLecture(lecture)
        recoveredURL = nil
        recoveredDuration = 0
        recoveredTitle = ""

        NotificationCenter.default.post(name: .lectureRecordingCompleted, object: nil)

        Task {
            await startTranscription(for: lecture)
        }
    }

    private func discardRecoveredRecording() {
        if let url = recoveredURL {
            try? FileManager.default.removeItem(at: url)
        }
        recoveredURL = nil
        recoveredDuration = 0
        recoveredTitle = ""
    }

    private func defaultRecordingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return "Lecture \(formatter.string(from: Date()))"
    }

    private func startTranscription(for lecture: Lecture) async {
        guard let audioURL = lecture.audioPath else { return }

        let lectureId = lecture.id
        let store = LectureStore.shared

        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        store.updateLecture(updatedLecture)

        // Progressive update: show partial transcript as each chunk completes
        // Read latest from store each time to avoid overwriting user's title edits
        transcriptionService.onChunkCompleted = { partialText, partialSegments in
            guard var latest = store.getLecture(by: lectureId) else { return }
            latest.transcriptText = partialText
            latest.transcriptSegments = partialSegments
            store.updateLecture(latest)
        }

        do {
            let result = try await transcriptionService.transcribe(audioURL: audioURL)

            transcriptionService.onChunkCompleted = nil
            guard var latest = store.getLecture(by: lectureId) else { return }
            latest.transcriptText = result.text
            latest.transcriptSegments = result.segments
            latest.transcriptStatus = .completed
            latest.language = transcriptionService.transcriptionLanguage
            store.updateLecture(latest)
        } catch {
            transcriptionService.onChunkCompleted = nil
            if var latest = store.getLecture(by: lectureId) {
                latest.transcriptStatus = .failed
                store.updateLecture(latest)
            }
            AppLogger.error("Transcription failed: \(error)", category: .recording)

            await MainActor.run {
                lastFailedLectureId = lecture.id
                transcriptionError = ErrorMessages.forTranscription(error)
                showTranscriptionErrorAlert = true
            }
        }
    }

    // MARK: - Helpers

    private func estimatedFileSize(_ duration: TimeInterval) -> String {
        let bytesPerSecond = 64_000.0 / 8.0
        let totalBytes = bytesPerSecond * duration
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

// MARK: - Recovery Sheet

private struct RecoverySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var courseName: String = ""
    let duration: TimeInterval
    let onSave: (String, String?) -> Void
    let onDiscard: () -> Void

    init(duration: TimeInterval, defaultTitle: String, onSave: @escaping (String, String?) -> Void, onDiscard: @escaping () -> Void) {
        self.duration = duration
        _title = State(initialValue: defaultTitle)
        self.onSave = onSave
        self.onDiscard = onDiscard
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .padding(.top, 24)

                Text("Recording Recovered")
                    .font(.title3.bold())

                Text("A previous recording was interrupted. We saved \(formatDuration(duration)) of audio.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    TextField("Lecture title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)

                    TextField("Course (optional)", text: $courseName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)
                }
                .padding(.horizontal, 24)

                Button(action: save) {
                    Text("Save Recording")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)

                Button("Discard") {
                    onDiscard()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.red)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func save() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCourse = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            finalTitle.isEmpty ? "Recovered Recording" : finalTitle,
            finalCourse.isEmpty ? nil : finalCourse
        )
        dismiss()
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
