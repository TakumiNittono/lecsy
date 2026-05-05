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
    @ObservedObject private var progress = TranscriptionProgressService.shared
    @State private var title: String
    @State private var lecture: Lecture
    // PERF: Cached, token-stripped transcript. `stripWhisperTokens` is a
    // regex scan over the entire transcript (tens of thousands of chars),
    // and the body used to call it on every re-render — including every
    // audio-player tick during playback — which made both opening and
    // playing a lecture visibly laggy. We now compute it once on appear
    // and whenever the transcript actually changes.
    @State private var cleanedTranscript: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isRetrying = false
    @State private var titleSaveTask: Task<Void, Never>?
    @State private var audioLoadError: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    // AI summary state is owned by SummaryGenerationStore so that navigating
    // away does not cancel generation. The view only holds the displayed
    // result; loading/streaming/error state is read from the store.
    @StateObject private var summaryStore = SummaryGenerationStore.shared
    @State private var summaryResult: SummaryService.SummaryResult?
    @AppStorage("summaryOutputLanguage") private var summaryOutputLanguage: String = "en"

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
    @ObservedObject private var planService = PlanService.shared

    init(lecture: Lecture) {
        _lecture = State(initialValue: lecture)
        _title = State(initialValue: lecture.title)
        // IMPORTANT: Keep init CHEAP. LibraryView uses the legacy
        // `NavigationView` + `NavigationLink(destination:)` API, which
        // eagerly constructs *every* destination for every row in the
        // ForEach. If we ran `stripWhisperTokens` on the full transcript
        // here, opening the Library with 50 long lectures would burn
        // seconds on the main thread. The clean transcript is populated
        // asynchronously in `.task` once this specific view actually
        // appears.
        _cleanedTranscript = State(initialValue: "")
    }

    // MARK: - Derived summary state (from SummaryGenerationStore)
    private var summaryGenerationState: SummaryGenerationStore.State {
        summaryStore.state(for: lecture.id)
    }
    private var summaryLoading: Bool { summaryGenerationState.loading }
    private var summaryError: String? { summaryGenerationState.error }
    /// Prefer live-streaming partial result, then final cached result.
    private var displayedSummary: SummaryService.SummaryResult? {
        summaryGenerationState.partialResult ?? summaryResult
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

                Divider()

                // Copy & Share buttons
                if let transcript = lecture.transcriptText, !transcript.isEmpty {
                    // Use cached clean transcript instead of re-running regex
                    // on every body re-render (audio player ticks would
                    // otherwise burn CPU on a full-document regex scan).
                    let cleanTranscript = cleanedTranscript
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
                            Button {
                                exportWithAudio()
                            } label: {
                                Label("Export Audio + Transcript", systemImage: "waveform.badge.plus")
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

                    // AI Summary — 認証済みユーザーのみ利用可。未サインインには静かなヒント。
                    if authService.isAuthenticated {
                        summarySection(transcript: cleanTranscript)
                    } else if !cleanTranscript.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.secondary)
                            Text("Sign in to generate an AI summary of this lecture.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 6)
                    }
                }

                // Cancel + Retry button (visible when stuck in processing)
                if lecture.transcriptStatus == .processing && !isRetrying {
                    // Peter Ullsperger 2026-05-05: 「Library を開くと過去の録音が
                    // ずっと Transcribing のまま」事象。kill / crash で死んだ
                    // lecture が永遠に processing 表示で残るため、ユーザーは
                    // 「処理中」と思って何時間も待つ。TranscriptionProgressService
                    // に active な stage が無い = TranscriptionService が現在
                    // 触ってない、という単純な fact で stuck を判定できる。
                    // detail を開いた瞬間に banner で告知して cancelAndRetryButton
                    // への動線を視覚的に強化する。
                    if progress.stages[lecture.id] == nil
                        && progress.chunkProgress[lecture.id] == nil {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This transcription looks stuck.")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Tap Cancel & Retry below to start over.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.orange.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                    }
                    cancelAndRetryButton
                }

                // Retry button (for failed or notStarted transcriptions)
                if lecture.transcriptStatus == .failed || lecture.transcriptStatus == .notStarted {
                    retryButton
                }

                // Re-transcribe (for completed transcriptions when audio still exists).
                // Covers the case where live captions captured only a small portion of
                // the lecture (low SNR / far-field mic) and the user wants to reprocess
                // the full audio with the batch engine offline.
                //
                // 自動サジェストが立っている場合（録音中 MOVE CLOSER が長く出ていた Pro
                // ユーザー）はバナー側に CTA を集約して、剥き出しのボタンは隠す。
                // それ以外（普通に綺麗に録れた・Free ユーザー・legacy データ）は従来通り
                // 控えめなボタンを出して、いつでも boost retry できる入口を残す。
                if lecture.transcriptStatus == .completed
                    && lecture.audioPath != nil
                    && !isRetrying {
                    if shouldSuggestAudioBoost {
                        audioBoostSuggestionBanner
                    } else {
                        reTranscribeButton
                    }
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
                                // Cold start (CoreML JIT compile) は実機初回で 80-130s
                                // かかる。「これは初回だけ」とユーザーに伝えないと
                                // 「Free だから遅いの?」「アプリ固まってる?」と
                                // 誤解されて評価が落ちる。`hasCompletedFirstModelLoad`
                                // が立っていない (=まだ一度も model load 完了してない)
                                // 時のみ表示することで、2 回目以降は出さない。
                                if !UserDefaults.standard.bool(forKey: "lecsy.hasCompletedFirstModelLoad") {
                                    Text("First-time setup. Future launches will be instant.")
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.blue.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text(progress.text(
                                        for: lecture.id,
                                        fallback: isRetrying ? "Retrying..." : "Transcribing..."
                                    ))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                // Chunk progress bar — gives the user an actual "how far am I"
                                // signal during long recordings (a 90 min lecture chunks into
                                // ≈119 pieces and can take 2-6 min on iPhone 13).
                                // index == 0 は RecordView が transcription 起動直後に貼る
                                // placeholder。model load (cold start で 80-130s) と VAD
                                // 完了を待つ間、indeterminate 線形 bar をアニメ表示して
                                // 「処理が動いている」を返す。最初の実 chunk が来たら
                                // determinate bar に切り替え、% で進捗を見せる。
                                if let cp = progress.chunkProgress[lecture.id] {
                                    if cp.index == 0 {
                                        ProgressView()
                                            .progressViewStyle(.linear)
                                            .tint(.blue.opacity(0.7))
                                            .frame(maxWidth: 280)
                                    } else {
                                        ProgressView(value: cp.fraction)
                                            .progressViewStyle(.linear)
                                            .tint(.blue.opacity(0.7))
                                            .frame(maxWidth: 280)
                                    }
                                }
                                // iOS pauses GPU work when the app is backgrounded, which
                                // stalls the chunk loop at the next safe boundary. Tell the
                                // user up-front so they don't switch apps mid-transcription
                                // and come back to a stuck "transcribing…" state.
                                HStack(spacing: 6) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .font(.caption2)
                                    Text("Keep Lecsy open — switching apps pauses transcription.")
                                        .font(.caption2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.06))
                                .clipShape(Capsule())
                            }
                        }

                        // Show partial transcript as it comes in
                        if let segments = lecture.transcriptSegments, !segments.isEmpty {
                            SyncedTranscriptView(
                                segments: segments,
                                currentTime: audioPlayer.currentTime,
                                isPlaying: audioPlayer.isPlaying,
                                bookmarks: [],
                                onSegmentTap: { time in
                                    audioPlayer.seek(to: time)
                                    if !audioPlayer.isPlaying {
                                        audioPlayer.play()
                                    }
                                }
                            )
                            .frame(minHeight: 200)
                        } else if !cleanedTranscript.isEmpty {
                            Text(cleanedTranscript)
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
                        bookmarks: [],
                        onSegmentTap: { time in
                            audioPlayer.seek(to: time)
                            if !audioPlayer.isPlaying {
                                audioPlayer.play()
                            }
                        }
                    )
                    .frame(minHeight: 200)
                } else if let transcript = lecture.transcriptText, !transcript.isEmpty {
                    // Prefer the cached clean text; if the regex hasn't run yet
                    // (first appear, before .task fires) fall back to raw so
                    // the user never sees an empty body for a completed lecture.
                    Text(cleanedTranscript.isEmpty ? transcript : cleanedTranscript)
                        .font(.body)
                } else if lecture.transcriptStatus == .failed {
                    // RecordView:1157-1166 で chunked path 失敗時に partial cache を
                    // 救済保存しているが、UI 側で「途中まで読める」を露出していない
                    // ため、ユーザーは赤字「failed」だけ見て諦めてしまっていた。
                    // partial text があれば「途中までは取れている、retry で続きを補完
                    // できる」事を明示する。0 を返してない事を見せる。
                    if let partial = lecture.transcriptText, !partial.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                                Text("Partial transcript saved — tap Retry to complete the rest.")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text(cleanedTranscript.isEmpty ? partial : cleanedTranscript)
                                .font(.body)
                        }
                    } else {
                        Text("Transcription failed")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                } else if lecture.transcriptStatus == .completed {
                    // 完了したのに transcript が空 = 録音は成功したが発話が無かった
                    // (silent recording)。"No transcript data" は誤解を招くので明示。
                    Text("No speech detected — the recording was silent.")
                        .font(.body)
                        .foregroundColor(.secondary)
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
        .task(id: lecture.transcriptText) {
            // Compute the token-stripped transcript off the main thread,
            // once per distinct raw text. Runs after the view has actually
            // appeared, so navigation push is never blocked.
            let raw = lecture.transcriptText ?? ""
            if raw.isEmpty {
                cleanedTranscript = ""
            } else {
                let cleaned = await Task.detached(priority: .userInitiated) {
                    TranscriptionResult.TranscriptionSegment.stripWhisperTokens(raw)
                }.value
                if !Task.isCancelled {
                    cleanedTranscript = cleaned
                }
            }
        }
        .onAppear {
            loadAudio()
            // Restore any cached AI summary so the user doesn't have to
            // regenerate it. If a different output language was saved, keep
            // the cached one visible and honor its language setting.
            if summaryResult == nil, let cached = lecture.cachedSummary {
                summaryResult = cached
                if let lang = lecture.cachedSummaryLanguage {
                    summaryOutputLanguage = lang
                }
            }
            // If we navigated away mid-generation and came back after the
            // store finished, pick up the newly-saved result from LectureStore.
            if let latest = LectureStore.shared.lectures.first(where: { $0.id == lecture.id }),
               let cached = latest.cachedSummary {
                summaryResult = cached
                lecture.cachedSummary = cached
                lecture.cachedSummaryLanguage = latest.cachedSummaryLanguage
            }
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
                // Refresh the cached clean transcript since raw text changed.
                cleanedTranscript = stored.transcriptText.map {
                    TranscriptionResult.TranscriptionSegment.stripWhisperTokens($0)
                } ?? ""
            }
            // Pick up AI summary saved by SummaryGenerationStore (e.g. when
            // generation finished while the user was on another screen).
            if stored.cachedSummary != lecture.cachedSummary {
                lecture.cachedSummary = stored.cachedSummary
                lecture.cachedSummaryLanguage = stored.cachedSummaryLanguage
                if let cached = stored.cachedSummary {
                    summaryResult = cached
                }
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
            if audioPlayer.isRepairing {
                // 「音声は何があっても死守する」(memory: feedback_audio_must_survive.md):
                // AVAudioPlayer init が失敗した m4a を AVAssetExportSession で再 mux
                // 修復している最中。29分の録音で数秒〜十数秒かかるので、ユーザーに
                // 何が起きているか見せる (黙って失敗 → 「壊れた」と誤認 を避ける)。
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Repairing audio…")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let error = audioLoadError {
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

    // MARK: - Audio Boost Suggestion (auto-prompt for low-SNR recordings)
    //
    // 録音中に MOVE CLOSER ピル (audioLevel < 0.08) が長く立っていた Pro ユーザーには、
    // 録音停止後に自動でバナーを出して boost retry を促す。お父様 (2026-04-24) の指摘
    // 「あとでオフラインで再認識したい」「録音状況が悪いことを後で気づいた」シナリオの解。
    //
    // 閾値: 録音時間の 30% 以上、または累積 120s 以上 (短い授業メモでも誤発火しないように
    // 比率と絶対秒の OR)。Free ユーザーは live が WhisperKit なので boost retry の差分が
    // 小さい → サジェストしない (Pro entitled のみ)。
    private var shouldSuggestAudioBoost: Bool {
        guard PlanService.shared.isProEntitled else { return false }
        guard let lowSeconds = lecture.lowAudioSeconds, lowSeconds > 0 else { return false }
        guard lecture.duration > 0 else { return false }
        let ratio = lowSeconds / lecture.duration
        return ratio >= 0.3 || lowSeconds >= 120
    }

    private var audioBoostSuggestionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio quality was low during parts of this lecture.")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Try re-transcribing with audio boost for a clearer transcript.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button(action: {
                // バナーを引っ込めるために lowAudioSeconds をクリアしてから retry を起動。
                // retry が失敗してももう一度同じバナーが出続けるのは煩わしいので、
                // 一度提案を受け入れた = サジェスト責務終了、と扱う。手動の boost retry は
                // 通常の reTranscribeButton から引き続きいつでも可能。
                var updated = lecture
                updated.lowAudioSeconds = nil
                store.updateLecture(updated)
                lecture = updated
                Task { await retryTranscription() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Re-transcribe with audio boost")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .clipShape(Capsule())
            }
            .disabled(isRetrying)
            .accessibilityHint("Reprocesses the saved audio with enhancement to recover speech the live captions missed")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Re-transcribe Button (for completed recordings)
    //
    // For lectures recorded in difficult acoustics (large halls, far-field mic)
    // the live-caption pass can capture only a fraction of the speech while the
    // m4a file still holds the full audio. This button lets the user re-run the
    // audio through the batch engine — which uses a different model and is
    // generally more forgiving of low-SNR input than the realtime stream.
    private var reTranscribeButton: some View {
        Button(action: {
            Task { await retryTranscription() }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                Text("Re-transcribe with audio boost")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.08))
            .clipShape(Capsule())
        }
        .disabled(isRetrying)
        .accessibilityLabel("Re-transcribe this recording from audio")
        .accessibilityHint("Reprocesses the saved audio when the live transcript missed parts of the lecture")
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

    // MARK: - AI Summary

    @ViewBuilder
    private func summarySection(transcript: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI Summary", systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                // Free + sign-in でも AI 要約は使えるが、その事実が UI に出ていな
                // かった (2026-04-29 Free 監査 P0)。Pro 限定機能と誤解する Free
                // ユーザーが「自分には押せないだろう」とそもそも触らない事故を防ぐ。
                if !planService.isPaid && authService.isAuthenticated {
                    Text("Free")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("Available on the Free plan")
                }

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
                        Text(summaryLanguages.first { $0.code == summaryOutputLanguage }?.label ?? "English")
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
                // Generate / Regenerate の gate ロジック。
                // 旧実装: `transcriptInProgress = (status != .completed)` で一括判定。
                //   → status が .failed でも (transcript text は揃ってるのに) Regenerate が
                //     ずっと disabled になる事故があった (お父様フィードバック 2026-04-26、
                //     1h6m 講演で transcribing がゾンビ化 → 再起動 → status が .failed/.processing
                //     のまま → Regenerate 不可)。
                // 新実装: Generate と Regenerate を別々の前提で gate する。
                //   - Generate: 完了した transcript が無いと文章を作れない → status == .completed 必須
                //   - Regenerate: 既に summary が cache されてる = 過去に transcript があった証左。
                //     言語切替などの再生成は transcript text さえあれば可能。
                //     transcribing が物理的に進行中の時 (.processing で text 更新が走る)
                //     のみ block する。
                let tooShort = lecture.duration < 60
                let hasTranscriptText = !(lecture.transcriptText?.isEmpty ?? true)
                let isActivelyTranscribing = lecture.transcriptStatus == .processing
                let disabledForGenerate = tooShort || lecture.transcriptStatus != .completed
                let disabledForRegenerate = tooShort || !hasTranscriptText || isActivelyTranscribing
                if summaryLoading {
                    ProgressView().scaleEffect(0.8)
                } else if displayedSummary == nil {
                    Button {
                        startSummary(content: transcript)
                    } label: {
                        Text("Generate")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(disabledForGenerate ? Color.gray : Color.blue)
                            .clipShape(Capsule())
                    }
                    .disabled(disabledForGenerate)
                } else {
                    Button {
                        startSummary(content: transcript)
                    } label: {
                        Text("Regenerate")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(disabledForRegenerate ? .gray : .blue)
                    }
                    .disabled(disabledForRegenerate)
                }
            }

            if lecture.duration < 60 && displayedSummary == nil {
                Text("Recordings under 1 minute can't be summarized.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // 「Generate」を押せない理由を、状態別に説明 (Regenerate は cached summary が
            // ある時しか出ないので説明不要)。
            if displayedSummary == nil {
                if lecture.transcriptStatus == .processing {
                    Text("Wait until transcription finishes before generating a summary.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                } else if lecture.transcriptStatus == .failed {
                    Text("Transcription failed — retry above before generating a summary.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                } else if lecture.transcriptStatus == .notStarted {
                    Text("Transcribe this recording before generating a summary.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            if let error = summaryError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red)
            }

            if let result = displayedSummary {
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

    /// Kick off summary generation via the shared store. The task lives in
    /// SummaryGenerationStore, so navigating away from this view keeps the
    /// generation alive and auto-saves the result to LectureStore on finish.
    private func startSummary(content: String) {
        // Clear any locally-cached result so `displayedSummary` falls back
        // to the live partial result emitted by the store.
        summaryResult = nil
        summaryStore.start(
            lecture: lecture,
            content: content,
            outputLanguage: summaryOutputLanguage
        )
    }

    private func languageDisplay(for code: String) -> String {
        summaryLanguages.first(where: { $0.code == code })?.label ?? code
    }

    @ViewBuilder
    private func summaryBlock(result: SummaryService.SummaryResult, languageLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Copy / Share — お父様フィードバック 2026-04-26: Transcript 直上の
            // Copy/Share が AI Summary をコピーしたように誤解された。AI Summary 専用
            // の動線をカード内に持つ。
            HStack(spacing: 12) {
                Spacer()
                CopyButton(text: summaryAsPlainText(result))
                Button {
                    shareSummary(result)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                        Text("Share")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .accessibilityLabel("Share AI summary")
            }

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
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let points = result.key_points, !points.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Points")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    ForEach(points, id: \.self) { p in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(.blue)
                            Text(p).font(.system(.body, design: .rounded))
                        }
                    }
                }
            }
            if let sections = result.sections, !sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.heading)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Text(section.content)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    /// AI Summary を Copy / Share 用のプレーンテキストへ。
    /// セクション順は UI 表示と揃える: summary → key points → sections。
    private func summaryAsPlainText(_ result: SummaryService.SummaryResult) -> String {
        var lines: [String] = []
        if let overall = result.summary, !overall.isEmpty {
            lines.append(overall)
        }
        if let points = result.key_points, !points.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Key Points")
            for p in points { lines.append("• \(p)") }
        }
        if let sections = result.sections, !sections.isEmpty {
            for section in sections {
                if !lines.isEmpty { lines.append("") }
                lines.append(section.heading)
                lines.append(section.content)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// AI Summary を Activity Sheet で共有。テキストのみ (markdown 化はしない —
    /// メール / メッセージで貼って読みやすい体裁を優先)。
    private func shareSummary(_ result: SummaryService.SummaryResult) {
        let plain = summaryAsPlainText(result)
        guard !plain.isEmpty else { return }
        var text = "\(lecture.displayTitle) — AI Summary\n\n"
        text += plain
        text += "\n\nGenerated with Lecsy — lecsy.app"
        shareItems = [text]
        showShareSheet = true
    }

    // MARK: - Helpers

    private func loadAudio() {
        guard let audioURL = lecture.audioPath else { return }
        // PERF: Run AVFoundation init off main so navigation push isn't
        // blocked by audio session + file parsing (was the "2 seconds to
        // open a lecture" culprit). audioPlayer is @MainActor so the task
        // comes back on main before touching @Published state.
        let savedPosition = lecture.lastPlaybackPosition
        Task {
            do {
                try await audioPlayer.loadAsync(url: audioURL)
                audioLoadError = nil
                if let savedPosition, savedPosition > 0,
                   savedPosition < audioPlayer.duration {
                    audioPlayer.seek(to: savedPosition)
                }
            } catch {
                audioLoadError = ErrorMessages.friendly(error)
            }
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

        // Sentry filter 用 flow tag。再文字起こし path 中の error を
        // Issue 一覧で `flow:re-transcribe` で絞れる。
        AppLogger.setSentryTag("flow", value: "re-transcribe")
        let durationBucket: String
        switch lecture.duration {
        case ..<300:        durationBucket = "<5min"
        case 300..<1800:    durationBucket = "5-30min"
        case 1800..<3600:   durationBucket = "30-60min"
        default:            durationBucket = ">60min"
        }
        AppLogger.setSentryTag("lecsy.audio_duration_bucket", value: durationBucket)

        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        store.updateLecture(updatedLecture)
        lecture = updatedLecture

        let transcriptionService = TranscriptionService.shared

        let progress = TranscriptionProgressService.shared
        progress.set(.preparing, for: lectureId)
        defer { progress.clear(for: lectureId) }

        // Free 経路: live decoder の cache が残っていれば即 stitch で完結。
        // 録音停止後に retry を押した場合や、起動時 recovery で .failed に
        // 落ちた場合に効く。Pro は cache を読まない (二重 gate)。
        if !PlanService.shared.isPaid {
            let completion = transcriptionService.liveCacheCompletion(
                lectureId: lectureId,
                totalDuration: lecture.duration
            )
            if completion.isComplete {
                let stitched = transcriptionService.stitchLiveCachedChunks(completion.chunks)
                if var latest = store.getLecture(by: lectureId) {
                    latest.transcriptText = stitched.text
                    latest.transcriptSegments = stitched.segments
                    latest.transcriptStatus = .completed
                    latest.language = transcriptionService.transcriptionLanguage
                    store.updateLecture(latest)
                    lecture = latest
                }
                transcriptionService.clearChunkCache(lectureId: lectureId)
                AppLogger.info("Re-transcribe completed via live cache (\(completion.chunks.count) chunks, coverage \(Int(completion.coverage))/\(Int(lecture.duration))s)", category: .transcription)
                isRetrying = false
                return
            } else if !completion.chunks.isEmpty {
                AppLogger.info("Re-transcribe: live cache incomplete (coverage \(Int(completion.coverage))/\(Int(lecture.duration))s, gaps=\(completion.gapCount)) — running chunked path", category: .transcription)
            }
        }

        // Pre-normalize the audio so faint far-field speech (large halls,
        // distant speaker) is lifted toward peak before transcription. Both
        // the Deepgram batch path and the WhisperKit fallback benefit equally
        // — the お父様 2026-04-24 case (1-hour 大講堂 recording, only 2 minutes
        // recognized) is the motivating scenario, and Free/WhisperKit-only
        // users hit it just as hard as Pro users. Best-effort: if enhancement
        // fails we fall through to raw audio.
        progress.set(.normalizing, for: lectureId)
        var transcribeURL = audioURL
        var enhancedURL: URL?
        do {
            let e = try await AudioEnhancementService.shared.enhance(audioURL: audioURL)
            enhancedURL = e
            transcribeURL = e
            AppLogger.info("Re-transcribe: audio enhanced before transcription", category: .transcription)
        } catch {
            AppLogger.warning("Audio enhancement failed (\(error.localizedDescription)) — using raw audio", category: .transcription)
        }
        progress.set(.transcribing, for: lectureId)

        defer {
            if let e = enhancedURL {
                try? FileManager.default.removeItem(at: e)
            }
        }

        // Primary path: Deepgram Prerecorded for Pro+auth users. Batch uses a
        // different model than the realtime stream and tends to recover speech
        // from low-SNR recordings (large halls, distant speaker) the live path
        // silently dropped. Fall back to WhisperKit on any failure so offline /
        // free users still get something.
        if AuthService.shared.isAuthenticated && PlanService.shared.isPaid {
            do {
                let dgResult = try await DeepgramBatchService.shared.transcribe(
                    audioURL: transcribeURL,
                    language: transcriptionService.transcriptionLanguage.deepgramCode
                )
                guard var latest = store.getLecture(by: lectureId) else {
                    isRetrying = false
                    return
                }
                latest.transcriptText = dgResult.text
                latest.transcriptSegments = dgResult.segments
                latest.transcriptStatus = .completed
                latest.language = transcriptionService.transcriptionLanguage
                store.updateLecture(latest)
                lecture = latest

                let snapshot = latest
                let langRaw = transcriptionService.transcriptionLanguage.rawValue
                Task {
                    await CloudSyncService.shared.uploadTranscriptIfEnabled(
                        clientId: snapshot.id,
                        title: snapshot.title,
                        content: dgResult.text,
                        createdAt: snapshot.createdAt,
                        durationSeconds: snapshot.duration,
                        language: langRaw
                    )
                }
                isRetrying = false
                return
            } catch {
                AppLogger.warning("Deepgram batch re-transcription failed (\(error.localizedDescription)) — falling back to WhisperKit", category: .transcription)
                // continue to WhisperKit fallback
            }
        }

        // Fallback: on-device WhisperKit with auto-retry (3 attempts, exponential
        // backoff). chunked path 内で cachedSegments の resume が効くので
        // 重複 decode は起きない。永続エラー (audio not found / too short) は
        // 即 abort。retry 中も partial text は逐次更新する。
        // audioLoadFailed (m4a moov atom 破損) は AVAssetExportSession で
        // 1 度だけ re-mux 修復を試みる (memory `feedback_audio_must_survive.md`)。
        let maxAttempts = 3
        var lastError: Error?
        var repairedURL: URL?
        var didAttemptRepair = false
        defer {
            if let r = repairedURL { try? FileManager.default.removeItem(at: r) }
        }
        for attempt in 1...maxAttempts {
            transcriptionService.onChunkCompleted = { partialText, partialSegments in
                guard var latest = store.getLecture(by: lectureId) else { return }
                latest.transcriptText = partialText
                latest.transcriptSegments = partialSegments
                store.updateLecture(latest)
                lecture = latest
            }
            do {
                // enhance が成功している (transcribeURL == enhancedURL) ときは
                // 既に正規化済なので、TranscriptionService 内の preprocessAudio
                // (フル PCM buffer alloc) を skip する。長尺で iPad memory budget を
                // 超えた sudden-death を回避する (Peter Ullsperger 2026-05-05 incident)。
                let alreadyEnhanced = (enhancedURL != nil) && (transcribeURL == enhancedURL)
                let result = try await transcriptionService.transcribe(
                    audioURL: transcribeURL,
                    lectureId: lectureId,
                    skipPreprocess: alreadyEnhanced
                )
                transcriptionService.onChunkCompleted = nil
                if var latest = store.getLecture(by: lectureId) {
                    latest.transcriptText = result.text
                    latest.transcriptSegments = result.segments
                    latest.transcriptStatus = .completed
                    latest.language = transcriptionService.transcriptionLanguage
                    store.updateLecture(latest)
                    lecture = latest
                }
                if attempt > 1 {
                    AppLogger.info("Re-transcribe succeeded on attempt \(attempt)/\(maxAttempts)", category: .transcription)
                }
                isRetrying = false
                return
            } catch {
                transcriptionService.onChunkCompleted = nil
                lastError = error
                // audioLoadFailed: 1 度だけ AVAssetExportSession で再 mux を試す。
                // 修復が成功したら transcribeURL を差し替えて attempt を消費せず continue。
                if !didAttemptRepair, let tx = error as? TranscriptionError, case .audioLoadFailed = tx {
                    didAttemptRepair = true
                    AppLogger.warning("Re-transcribe got audioLoadFailed — attempting m4a re-mux repair", category: .transcription)
                    if let repaired = try? await AudioEnhancementService.shared.repair(audioURL: transcribeURL) {
                        repairedURL = repaired
                        transcribeURL = repaired
                        AppLogger.info("Re-transcribe: audio repaired — retrying on re-muxed file", category: .transcription)
                        continue
                    } else {
                        AppLogger.warning("Re-transcribe: audio repair failed — abandoning", category: .transcription)
                        break
                    }
                }
                // 永続エラーは retry しない
                if let tx = error as? TranscriptionError {
                    switch tx {
                    case .audioFileNotFound, .audioFileTooShort, .modelNotLoaded:
                        break // 即 abort
                    case .audioLoadFailed:
                        // repair 失敗 / 2 回目で出ている = 救えない。abort。
                        break
                    default:
                        if attempt < maxAttempts {
                            let backoffSeconds = Double(attempt) * 2.0
                            AppLogger.warning("Re-transcribe attempt \(attempt)/\(maxAttempts) failed (\(error.localizedDescription)) — retrying in \(Int(backoffSeconds))s", category: .transcription)
                            try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                            continue
                        }
                    }
                } else if attempt < maxAttempts {
                    let backoffSeconds = Double(attempt) * 2.0
                    AppLogger.warning("Re-transcribe attempt \(attempt)/\(maxAttempts) failed (\(error.localizedDescription)) — retrying in \(Int(backoffSeconds))s", category: .transcription)
                    try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                    continue
                }
                break
            }
        }

        // 全 attempt 失敗 → 拾える partial cache だけでも反映しておく
        if let lastError = lastError {
            AppLogger.captureFingerprinted(
                lastError,
                fingerprint: ["re-transcribe", "all_attempts_failed"],
                tags: [
                    "audio_duration_bucket": (lecture.duration < 300 ? "<5min" : (lecture.duration < 1800 ? "5-30min" : (lecture.duration < 3600 ? "30-60min" : ">60min")))
                ],
                category: .transcription
            )
        }
        let partial = transcriptionService.loadLiveDecodedChunks(lectureId: lectureId)
        if !partial.isEmpty {
            let stitched = transcriptionService.stitchLiveCachedChunks(partial)
            if var latest = store.getLecture(by: lectureId) {
                latest.transcriptText = stitched.text
                latest.transcriptSegments = stitched.segments
                latest.transcriptStatus = .failed
                store.updateLecture(latest)
                lecture = latest
            }
            AppLogger.warning("Re-transcribe failed after retries — saved partial cache (\(partial.count) chunks)", category: .transcription)
        } else if var latest = store.getLecture(by: lectureId) {
            latest.transcriptStatus = .failed
            store.updateLecture(latest)
            lecture = latest
        }

        errorMessage = ErrorMessages.friendly(lastError ?? TranscriptionError.transcriptionFailed)
        showErrorAlert = true
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
            errorMessage = "Failed to export Markdown. Please try again."
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
            errorMessage = "Failed to export PDF. Please try again."
            showErrorAlert = true
        }
    }

    /// Export audio file (if present) plus a .txt with title, transcript, and
    /// any in-memory AI summary. Items are passed to the existing share sheet.
    private func exportWithAudio() {
        var items: [Any] = []

        // Build text payload
        var text = "\(lecture.displayTitle)\n\n"
        if let transcript = lecture.transcriptText, !transcript.isEmpty {
            text += "[Transcript]\n"
            text += TranscriptionResult.TranscriptionSegment.stripWhisperTokens(transcript)
            text += "\n\n"
        }
        if let summary = summaryResult?.summary, !summary.isEmpty {
            text += "[Summary]\n"
            text += summary
            text += "\n"
        }

        let safeTitle = lecture.displayTitle.replacingOccurrences(of: "/", with: "-")
        let txtURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeTitle).txt")
        do {
            try text.write(to: txtURL, atomically: true, encoding: .utf8)
            items.append(txtURL)
        } catch {
            errorMessage = "Failed to prepare export. Please try again."
            showErrorAlert = true
            return
        }

        // Audio file (if it exists on disk)
        if let audioPath = lecture.audioPath,
           FileManager.default.fileExists(atPath: audioPath.path) {
            items.append(audioPath)
        }

        shareItems = items
        showShareSheet = true
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
