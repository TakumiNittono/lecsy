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
    @StateObject private var syncService = SyncService.shared
    @StateObject private var authService = AuthService.shared
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

    init(lecture: Lecture) {
        _lecture = State(initialValue: lecture)
        _title = State(initialValue: lecture.title)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title editing
                TextField("Title", text: $title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: title) { _, newValue in
                        // Debounce: save to disk and sync to web after 500ms of inactivity
                        titleSaveTask?.cancel()
                        titleSaveTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            guard !Task.isCancelled else { return }

                            var updatedLecture = lecture
                            updatedLecture.title = newValue
                            store.updateLecture(updatedLecture)
                            lecture = updatedLecture

                            if lecture.savedToWeb, lecture.webTranscriptId != nil {
                                do {
                                    try await syncService.updateTitleOnWeb(lecture: updatedLecture, newTitle: newValue)
                                } catch {
                                    AppLogger.warning("LectureDetailView: Web title update failed - \(error.localizedDescription)", category: .sync)
                                }
                            }
                        }
                    }

                // Metadata
                HStack {
                    Label(lecture.formattedDuration, systemImage: "clock")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(lecture.createdAt, style: .date)
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)

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
                    HStack(spacing: 20) {
                        Spacer()
                        CopyButton(text: transcript)

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
                            if lecture.savedToWeb, lecture.webTranscriptId != nil {
                                Divider()
                                Button {
                                    shareLink()
                                } label: {
                                    Label("Share Web Link", systemImage: "link")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.body)
                            .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Share or export transcript")
                    }
                    .padding(.bottom, 8)
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
                            Text(transcript)
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
        VStack(spacing: 8) {
            if let error = audioLoadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    // Play/Pause button
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.play()
                        }
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

                    VStack(spacing: 4) {
                        // Seek slider
                        Slider(
                            value: Binding(
                                get: { audioPlayer.currentTime },
                                set: { audioPlayer.seek(to: $0) }
                            ),
                            in: 0...max(audioPlayer.duration, 0.01)
                        )
                        .accessibilityLabel("Seek through audio")

                        // Time labels
                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTime(audioPlayer.duration))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Speed button
                    Button(action: {
                        audioPlayer.cycleRate()
                    }) {
                        Text(formatRate(audioPlayer.playbackRate))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 30)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("Playback speed \(formatRate(audioPlayer.playbackRate))")
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
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
                Text(lecture.transcriptStatus == .notStarted ? "Transcribe" : "Retry Transcription")
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .cornerRadius(8)
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
                Text("Cancel & Retry")
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .cornerRadius(8)
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
                text += "[\(timestamp)] \(segment.text)\n"
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
                md += "\(segment.text)\n\n"
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

    private func shareLink() {
        guard let webId = lecture.webTranscriptId else { return }
        let url = SupabaseConfig.webBaseURL.appendingPathComponent("app/t/\(webId.uuidString)")
        shareItems = [url]
        showShareSheet = true
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
                content.append(NSAttributedString(string: segment.text + "\n", attributes: bodyAttrs))
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
