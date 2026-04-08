//
//  LectureDetailView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import CoreText

struct LectureDetailView: View {
    @StateObject private var store = LectureStore.shared
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @ObservedObject private var transcriptionStatus = TranscriptionService.shared
    @State private var title: String
    @State private var lecture: Lecture
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isRetrying = false
    @State private var titleSaveTask: Task<Void, Never>?
    @State private var audioLoadError: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var editingBookmark: LectureBookmark?
    @State private var editingBookmarkLabel: String = ""
    // AI summary state (in-memory; not persisted to local store yet)
    @State private var summaryResult: SummaryService.SummaryResult?
    @State private var summaryLoading = false
    @State private var summaryError: String?
    @AppStorage("summaryOutputLanguage") private var summaryOutputLanguage: String = "ja"

    private let summaryLanguages: [(code: String, label: String)] = [
        ("ja", "日本語"),
        ("en", "English"),
        ("zh", "中文"),
        ("ko", "한국어"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
    ]
    @ObservedObject private var authService = AuthService.shared

    init(lecture: Lecture) {
        _lecture = State(initialValue: lecture)
        _title = State(initialValue: lecture.title)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title editing
                TextField("Title", text: $title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .textFieldStyle(.plain)
                    .onChange(of: title) { _, newValue in
                        titleSaveTask?.cancel()
                        titleSaveTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            guard !Task.isCancelled else { return }

                            var updatedLecture = lecture
                            updatedLecture.title = newValue
                            store.updateLecture(updatedLecture)
                            lecture = updatedLecture
                        }
                    }

                // Metadata pills
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(lecture.formattedDuration)
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(lecture.createdAt, style: .date)
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())

                    Spacer()
                }

                // Audio Player
                if lecture.audioPath != nil {
                    audioPlayerSection
                }

                // Bookmark pills
                if !lecture.bookmarks.isEmpty {
                    bookmarkPillsSection
                }

                Divider()

                // Copy & Share buttons
                if let transcript = lecture.transcriptText, !transcript.isEmpty {
                    let cleanTranscript = TranscriptionResult.TranscriptionSegment.stripWhisperTokens(transcript)
                    HStack(spacing: 10) {
                        Spacer()
                        CopyButton(text: cleanTranscript)

                        Menu {
                            Button {
                                shareAsText()
                            } label: {
                                Label("Share as Text", systemImage: "doc.plaintext")
                            }
                            Button {
                                shareAsMarkdown()
                            } label: {
                                Label("Export Markdown", systemImage: "text.document")
                            }
                            Button {
                                shareAsPDF()
                            } label: {
                                Label("Export PDF", systemImage: "doc.richtext")
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13))
                                Text("Share")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .accessibilityLabel("Share or export transcript")
                    }
                    .padding(.bottom, 4)

                    // AI Summary — Web 経由で組織登録した B2B メンバーのみ
                    if authService.isOrgMember {
                        summarySection(transcript: cleanTranscript)
                    }
                }

                // Cancel + Retry button (visible when stuck in processing)
                if lecture.transcriptStatus == .processing && !isRetrying {
                    cancelAndRetryButton
                }

                // Retry button (for failed or notStarted transcriptions)
                if lecture.transcriptStatus == .failed || lecture.transcriptStatus == .notStarted {
                    retryButton
                }

                // Transcript text
                if lecture.transcriptStatus == .processing || (isRetrying && lecture.transcriptStatus != .completed) {
                    VStack(spacing: 12) {
                        if transcriptionStatus.state == .downloading {
                            // Model is being downloaded — show specific download progress
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text(transcriptionStatus.downloadStatusText.isEmpty
                                         ? "Preparing AI model..."
                                         : transcriptionStatus.downloadStatusText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if transcriptionStatus.downloadElapsedSeconds > 0 {
                                    Text(formatDownloadTime(transcriptionStatus.downloadElapsedSeconds))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                Text("Your lecture will be transcribed automatically when ready")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(isRetrying ? "Retrying..." : "Transcribing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Show partial transcript as it comes in
                        if let segments = lecture.transcriptSegments, !segments.isEmpty {
                            SyncedTranscriptView(
                                segments: segments,
                                currentTime: audioPlayer.currentTime,
                                isPlaying: audioPlayer.isPlaying,
                                bookmarks: lecture.bookmarks,
                                onSegmentTap: { time in
                                    audioPlayer.seek(to: time)
                                    if !audioPlayer.isPlaying {
                                        audioPlayer.play()
                                    }
                                }
                            )
                            .frame(minHeight: 200)
                        } else if let transcript = lecture.transcriptText, !transcript.isEmpty {
                            Text(TranscriptionResult.TranscriptionSegment.stripWhisperTokens(transcript))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if let segments = lecture.transcriptSegments, !segments.isEmpty {
                    SyncedTranscriptView(
                        segments: segments,
                        currentTime: audioPlayer.currentTime,
                        isPlaying: audioPlayer.isPlaying,
                        bookmarks: lecture.bookmarks,
                        onSegmentTap: { time in
                            audioPlayer.seek(to: time)
                            if !audioPlayer.isPlaying {
                                audioPlayer.play()
                            }
                        }
                    )
                    .frame(minHeight: 200)
                } else if let transcript = lecture.transcriptText, !transcript.isEmpty {
                    Text(transcript)
                        .font(.body)
                } else if lecture.transcriptStatus == .failed {
                    Text("Transcription failed")
                        .font(.body)
                        .foregroundColor(.red)
                } else if lecture.transcriptStatus != .notStarted {
                    Text("No transcript data")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Lecture")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Save playback position before leaving
            if audioPlayer.duration > 0 && audioPlayer.currentTime > 1 {
                var updatedLecture = lecture
                // Don't save if at the very end (finished playing)
                if audioPlayer.currentTime < audioPlayer.duration - 1 {
                    updatedLecture.lastPlaybackPosition = audioPlayer.currentTime
                } else {
                    updatedLecture.lastPlaybackPosition = nil
                }
                store.updateLecture(updatedLecture)
                lecture = updatedLecture
            }
            audioPlayer.stop()
        }
        .onAppear {
            loadAudio()
        }
        .onChange(of: store.lectures) { _, newLectures in
            // Sync transcript updates from external sources (e.g. RecordView's onChunkCompleted)
            guard let stored = newLectures.first(where: { $0.id == lecture.id }) else { return }
            // Only sync transcript-related fields to avoid overwriting user's title edits
            if stored.transcriptText != lecture.transcriptText
                || stored.transcriptStatus != lecture.transcriptStatus
                || stored.transcriptSegments != lecture.transcriptSegments {
                lecture.transcriptText = stored.transcriptText
                lecture.transcriptSegments = stored.transcriptSegments
                lecture.transcriptStatus = stored.transcriptStatus
                lecture.language = stored.language
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: showShareSheet) { _, show in
            if show {
                presentShareSheet()
            }
        }
    }

    // MARK: - Audio Player Section

    private var audioPlayerSection: some View {
        VStack(spacing: 10) {
            if let error = audioLoadError {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Button {
                        loadAudio()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Retry")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            } else {
                // Progress slider
                VStack(spacing: 2) {
                    Slider(
                        value: Binding(
                            get: { audioPlayer.currentTime },
                            set: { audioPlayer.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayer.duration, 0.01)
                    )
                    .tint(.accentColor)
                    .accessibilityLabel("Seek through audio")

                    HStack {
                        Text(formatTime(audioPlayer.currentTime))
                        Spacer()
                        Text("-\(formatTime(max(0, audioPlayer.duration - audioPlayer.currentTime)))")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                }

                // Controls row
                HStack(spacing: 16) {
                    Spacer()

                    // Speed button
                    Button(action: {
                        audioPlayer.cycleRate()
                    }) {
                        Text(formatRate(audioPlayer.playbackRate))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 32)
                            .background(Color.accentColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Playback speed \(formatRate(audioPlayer.playbackRate))")

                    // Play/Pause button
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.play()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 48, height: 48)
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .offset(x: audioPlayer.isPlaying ? 0 : 2)
                        }
                        .shadow(color: .accentColor.opacity(0.2), radius: 6, y: 3)
                    }
                    .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 32)

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Retry Button

    private var retryButton: some View {
        Button(action: {
            Task {
                await retryTranscription()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text(lecture.transcriptStatus == .notStarted ? "Transcribe" : "Retry Transcription")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .clipShape(Capsule())
            .shadow(color: .accentColor.opacity(0.2), radius: 6, y: 3)
        }
        .disabled(isRetrying)
    }

    // MARK: - Cancel & Retry Button

    private var cancelAndRetryButton: some View {
        Button(action: {
            TranscriptionService.shared.cancelTranscription()
            var updatedLecture = lecture
            updatedLecture.transcriptStatus = .failed
            store.updateLecture(updatedLecture)
            lecture = updatedLecture
        }) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text("Cancel & Retry")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.orange)
            .clipShape(Capsule())
        }
    }

    // MARK: - Bookmark Pills

    private var bookmarkPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(lecture.bookmarks.sorted(by: { $0.timestamp < $1.timestamp })) { bookmark in
                    Button {
                        audioPlayer.seek(to: bookmark.timestamp)
                        if !audioPlayer.isPlaying {
                            audioPlayer.play()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2)
                            Text(formatTime(bookmark.timestamp))
                                .font(.caption2)
                                .monospacedDigit()
                            if bookmark.label != "Bookmark" {
                                Text(bookmark.label)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }
                    .contextMenu {
                        Button {
                            editingBookmark = bookmark
                            editingBookmarkLabel = bookmark.label
                        } label: {
                            Label("Edit Label", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteBookmark(bookmark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .alert("Edit Bookmark", isPresented: Binding(
            get: { editingBookmark != nil },
            set: { if !$0 { editingBookmark = nil } }
        )) {
            TextField("Label", text: $editingBookmarkLabel)
            Button("Save") {
                if let bookmark = editingBookmark {
                    updateBookmarkLabel(bookmark, newLabel: editingBookmarkLabel)
                }
                editingBookmark = nil
            }
            Button("Cancel", role: .cancel) {
                editingBookmark = nil
            }
        }
    }

    // MARK: - AI Summary

    @ViewBuilder
    private func summarySection(transcript: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI Summary", systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                Menu {
                    ForEach(summaryLanguages, id: \.code) { lang in
                        Button {
                            summaryOutputLanguage = lang.code
                        } label: {
                            if summaryOutputLanguage == lang.code {
                                Label(lang.label, systemImage: "checkmark")
                            } else {
                                Text(lang.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(summaryLanguages.first { $0.code == summaryOutputLanguage }?.label ?? "日本語")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
                .disabled(summaryLoading)

                Spacer()
                let tooShort = lecture.duration < 60
                if summaryLoading {
                    ProgressView().scaleEffect(0.8)
                } else if summaryResult == nil {
                    Button {
                        Task { await runSummary(content: transcript) }
                    } label: {
                        Text("Generate")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(tooShort ? Color.gray : Color.blue)
                            .clipShape(Capsule())
                    }
                    .disabled(tooShort)
                } else {
                    Button {
                        Task { await runSummary(content: transcript) }
                    } label: {
                        Text("Regenerate")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(tooShort ? .gray : .blue)
                    }
                    .disabled(tooShort)
                }
            }

            if lecture.duration < 60 && summaryResult == nil {
                Text("Recordings under 1 minute can't be summarized.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if let error = summaryError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red)
            }

            if let result = summaryResult {
                summaryBlock(
                    result: result,
                    languageLabel: nil
                )
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 4)
    }

    private func runSummary(content: String) async {
        summaryError = nil
        summaryLoading = true
        defer { summaryLoading = false }
        do {
            let result = try await SummaryService.shared.generateSummary(
                title: lecture.title,
                content: content,
                durationSeconds: lecture.duration,
                language: lecture.language.rawValue,
                outputLanguage: summaryOutputLanguage
            )
            summaryResult = result
        } catch {
            summaryError = error.localizedDescription
        }
    }

    private func languageDisplay(for code: String) -> String {
        summaryLanguages.first(where: { $0.code == code })?.label ?? code
    }

    @ViewBuilder
    private func summaryBlock(result: SummaryService.SummaryResult, languageLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = languageLabel {
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            if let overall = result.summary, !overall.isEmpty {
                Text(overall)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let points = result.key_points, !points.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Points")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    ForEach(points, id: \.self) { p in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(.blue)
                            Text(p).font(.system(.caption, design: .rounded))
                        }
                    }
                }
            }
            if let sections = result.sections, !sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.heading)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                            Text(section.content)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func deleteBookmark(_ bookmark: LectureBookmark) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var updatedLecture = lecture
        updatedLecture.bookmarks.removeAll { $0.id == bookmark.id }
        store.updateLecture(updatedLecture)
        lecture = updatedLecture
    }

    private func updateBookmarkLabel(_ bookmark: LectureBookmark, newLabel: String) {
        var updatedLecture = lecture
        if let index = updatedLecture.bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            updatedLecture.bookmarks[index].label = newLabel
            store.updateLecture(updatedLecture)
            lecture = updatedLecture
        }
    }

    // MARK: - Helpers

    private func loadAudio() {
        guard let audioURL = lecture.audioPath else { return }
        do {
            try audioPlayer.load(url: audioURL)
            audioLoadError = nil
            // Restore saved playback position
            if let savedPosition = lecture.lastPlaybackPosition,
               savedPosition > 0 && savedPosition < audioPlayer.duration {
                audioPlayer.seek(to: savedPosition)
            }
        } catch {
            audioLoadError = error.localizedDescription
        }
    }

    private func retryTranscription() async {
        guard let audioURL = lecture.audioPath else {
            errorMessage = "Audio file not found"
            showErrorAlert = true
            return
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file not found"
            showErrorAlert = true
            return
        }

        isRetrying = true
        let lectureId = lecture.id

        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        store.updateLecture(updatedLecture)
        lecture = updatedLecture

        // Progressive update: read latest from store to avoid overwriting title edits
        let transcriptionService = TranscriptionService.shared
        transcriptionService.onChunkCompleted = { partialText, partialSegments in
            guard var latest = store.getLecture(by: lectureId) else { return }
            latest.transcriptText = partialText
            latest.transcriptSegments = partialSegments
            store.updateLecture(latest)
            lecture = latest
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
            lecture = latest
        } catch {
            transcriptionService.onChunkCompleted = nil
            if var latest = store.getLecture(by: lectureId) {
                latest.transcriptStatus = .failed
                store.updateLecture(latest)
                lecture = latest
            }

            errorMessage = error.localizedDescription
            showErrorAlert = true
        }

        isRetrying = false
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDownloadTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d elapsed", m, s)
    }

    private func formatRate(_ rate: Float) -> String {
        if rate == Float(Int(rate)) {
            return "\(Int(rate))x"
        }
        return String(format: "%.1fx", rate)
    }

    // MARK: - Share Presentation

    private func presentShareSheet() {
        guard !shareItems.isEmpty else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            showShareSheet = false
            return
        }
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            showShareSheet = false
        }
        // iPad popover support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    // MARK: - Share / Export

    private func shareAsText() {
        guard let transcript = lecture.transcriptText else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var text = """
        \(lecture.displayTitle)
        \(dateFormatter.string(from: lecture.createdAt)) | \(lecture.formattedDuration)

        """

        // Add timestamped segments if available
        if let segments = lecture.transcriptSegments, !segments.isEmpty {
            for segment in segments {
                let timestamp = formatTime(segment.startTime)
                text += "[\(timestamp)] \(segment.cleanText)\n"
            }
        } else {
            text += transcript
        }

        text += "\n\nTranscribed with Lecsy — free at lecsy.app"

        shareItems = [text]
        showShareSheet = true
    }

    private func shareAsMarkdown() {
        guard let transcript = lecture.transcriptText else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var md = "# \(lecture.displayTitle)\n\n"
        md += "**Date:** \(dateFormatter.string(from: lecture.createdAt))  \n"
        md += "**Duration:** \(lecture.formattedDuration)  \n"
        if let course = lecture.courseName {
            md += "**Course:** \(course)  \n"
        }
        md += "**Language:** \(lecture.language.displayName)  \n\n"

        // Bookmarks
        if !lecture.bookmarks.isEmpty {
            md += "## Bookmarks\n\n"
            for bookmark in lecture.bookmarks.sorted(by: { $0.timestamp < $1.timestamp }) {
                md += "- **[\(formatTime(bookmark.timestamp))]** \(bookmark.label)\n"
            }
            md += "\n"
        }

        md += "## Transcript\n\n"

        if let segments = lecture.transcriptSegments, !segments.isEmpty {
            for segment in segments {
                md += "> [\(formatTime(segment.startTime))]\n\n"
                md += "\(segment.cleanText)\n\n"
            }
        } else {
            md += transcript
        }

        md += "\n---\n*Transcribed with [Lecsy](https://lecsy.app) — free AI lecture transcription*\n"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(lecture.displayTitle).md")
        do {
            try md.write(to: tempURL, atomically: true, encoding: .utf8)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            errorMessage = "Failed to export Markdown: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func shareAsPDF() {
        guard let transcript = lecture.transcriptText else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        // Build content with branding and timestamps
        let content = NSMutableAttributedString()

        // Brand header
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.systemBlue
        ]
        content.append(NSAttributedString(string: "lecsy — AI Lecture Transcription\n\n", attributes: brandAttrs))

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        content.append(NSAttributedString(string: lecture.displayTitle, attributes: titleAttrs))
        content.append(NSAttributedString(string: "\n"))

        // Metadata
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        var metaLine = "\(dateFormatter.string(from: lecture.createdAt))  |  \(lecture.formattedDuration)"
        if let course = lecture.courseName {
            metaLine += "  |  \(course)"
        }
        content.append(NSAttributedString(string: metaLine + "\n\n", attributes: metaAttrs))

        // Bookmarks summary
        if !lecture.bookmarks.isEmpty {
            let bookmarkHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            content.append(NSAttributedString(string: "Bookmarks\n", attributes: bookmarkHeaderAttrs))
            for bookmark in lecture.bookmarks.sorted(by: { $0.timestamp < $1.timestamp }) {
                let bkAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.systemOrange
                ]
                content.append(NSAttributedString(string: "  [\(formatTime(bookmark.timestamp))] \(bookmark.label)\n", attributes: bkAttrs))
            }
            content.append(NSAttributedString(string: "\n"))
        }

        // Transcript body with timestamps
        if let segments = lecture.transcriptSegments, !segments.isEmpty {
            let timestampAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.systemBlue
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            for segment in segments {
                content.append(NSAttributedString(string: "[\(formatTime(segment.startTime))] ", attributes: timestampAttrs))
                content.append(NSAttributedString(string: segment.cleanText + "\n", attributes: bodyAttrs))
            }
        } else {
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            content.append(NSAttributedString(string: transcript, attributes: bodyAttrs))
        }

        // Footer branding
        content.append(NSAttributedString(string: "\n\nTranscribed with Lecsy — free at lecsy.app", attributes: brandAttrs))

        let textRect = CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            let framesetter = CTFramesetterCreateWithAttributedString(content)
            var charIndex = 0
            let totalLength = content.length

            while charIndex < totalLength {
                context.beginPage()
                let path = CGPath(rect: textRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(charIndex, 0), path, nil)
                let ctx = context.cgContext
                ctx.translateBy(x: 0, y: pageHeight)
                ctx.scaleBy(x: 1.0, y: -1.0)
                CTFrameDraw(frame, ctx)
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                charIndex += visibleRange.length
                if visibleRange.length == 0 { break }
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(lecture.displayTitle).pdf")
        do {
            try data.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            errorMessage = "Failed to export PDF: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

#Preview {
    NavigationView {
        LectureDetailView(lecture: Lecture(
            title: "Sample Lecture",
            createdAt: Date(),
            duration: 3600,
            transcriptText: "This is a sample transcript text."
        ))
    }
}
