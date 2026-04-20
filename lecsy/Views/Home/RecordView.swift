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
    @StateObject private var orgService = OrganizationService.shared
    @StateObject private var authService = AuthService.shared
    @StateObject private var liveCoordinator = TranscriptionCoordinator.shared
    @StateObject private var ferpaConsent = FERPAConsentService.shared
    @State private var showLoginSheet = false
    @State private var currentLanguageDisplay: String = TranscriptionService.shared.transcriptionLanguage.displayName
    @AppStorage("lecsy.hasAcceptedAIConsent") private var hasAcceptedAIConsent = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var ringPulse = false
    @State private var isMaxDurationStop = false

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: account chip (非録音時のみ)
                if !recordingService.isRecording {
                    HStack(spacing: 8) {
                        accountChip
                        FreeCampaignBanner()
                    }
                    .padding(.top, 8)
                }

                // Timer を一番上に配置（録音中の視認性優先）
                timerDisplay
                    .padding(.top, recordingService.isRecording ? 16 : 12)
                    .padding(.bottom, 8)

                // Status（Timer直下）
                statusIndicator
                    .padding(.bottom, 12)

                Spacer()

                // 中央: リアルタイム字幕。prepare 中（接続待ち）も表示して "Connecting…" を出す
                if recordingService.isRecording &&
                   (liveCoordinator.isLiveActive || liveCoordinator.isPreparing) {
                    LiveCaptionView(coordinator: liveCoordinator)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // 再接続中バナー（ネット断・電話・background 復帰などで session 張り直し中）
                if recordingService.isRecording && liveCoordinator.isReconnectingLive {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("ライブ字幕を再接続中…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.opacity)
                }

                Spacer()

                // Waveform（録音ボタンの上、視覚フィードバック）
                waveformDisplay
                    .padding(.bottom, 8)

                // Max duration warning (shows 5 min before auto-stop)
                maxDurationWarning
                    .padding(.bottom, 4)

                // Low audio warning
                lowAudioWarning
                    .padding(.bottom, 4)

                // Bookmark toast
                bookmarkToast
                    .padding(.bottom, 16)

                // Main control buttons
                controlButtons
                    .padding(.bottom, 12)

                // Bookmark count
                bookmarkCount
                    .padding(.bottom, 8)

                // Idle hint
                idleHint

                Spacer()
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
        .sheet(isPresented: $ferpaConsent.shouldPromptConsent) {
            FERPAConsentView(orgName: orgService.currentOrganization?.name ?? "your organization") {
                // Consent persisted; service flips shouldPromptConsent to false
                // and the sheet dismisses via the binding.
            }
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
                withAnimation { ringPulse = false }
            } else {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    ringPulse = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: TranscriptionService.languageDidChangeNotification)) { _ in
            currentLanguageDisplay = TranscriptionService.shared.transcriptionLanguage.displayName
        }
        .sheet(isPresented: $showLoginSheet) {
            NavigationStack {
                LoginView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showLoginSheet = false }
                        }
                    }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthed in
            if isAuthed { showLoginSheet = false }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(
                selectedLanguage: transcriptionService.transcriptionLanguage,
                onSelect: { language in
                    // view update 中の @Published 書き換えを避ける
                    DispatchQueue.main.async {
                        transcriptionService.setLanguage(language)
                        currentLanguageDisplay = language.displayName
                        showLanguagePicker = false
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTitleSheet) {
            TitleInputSheet(defaultTitle: defaultRecordingTitle()) { title, courseName, classId in
                Task { @MainActor in
                    await saveLecture(title: title, courseName: courseName, classId: classId)
                }
            }
        }
        .sheet(isPresented: $showRecoverySheet) {
            RecoverySheet(
                duration: recoveredDuration,
                defaultTitle: recoveredTitle,
                isMaxDuration: isMaxDurationStop
            ) { title, courseName in
                saveRecoveredLecture(title: title, courseName: courseName)
            } onDiscard: {
                discardRecoveredRecording()
            }
        }
        .onAppear {
            recordingService.prepareAudioSession()

            // 教室パイロットでは Record ボタンを押した瞬間に system 権限ダイアログが
            // 出ると、慌てて「Don't Allow」を押してしまう学生が必ず出る。
            // 表示直後に非同期で要求しておけば、赤ボタンを押す頃には既に
            // 権限が確定している (許可なら即録音、拒否なら設定遷移ボタンが出る)。
            // 既に許可/拒否済みの場合 system は何も出さないので副作用はない。
            if AVAudioSession.sharedInstance().recordPermission == .undetermined {
                Task { _ = await recordingService.requestMicrophonePermission() }
            }

            // Deepgram 先行接続を即座にキック。PlanService はキャッシュ済 plan を
            // 起動時 UserDefaults から読んでいるので同期で判定できる。
            // refresh() を await してから prepare すると 500ms-2s 遅れて
            // 「録音画面開いてから字幕 ready までラグがある」感になる。
            // prepare() は二重起動ガード付き、30秒放置で自動再張替え、失敗しても throw しない。
            if PlanService.shared.isPaid, !recordingService.isRecording {
                Task { await TranscriptionCoordinator.shared.prepare() }
            }

            // plan を最新化（JWT 更新直後 / 長時間放置後などで変化する可能性）。
            // prepare と並列に走らせる。refresh の結果 Pro になった場合のみ追加で prepare。
            Task {
                let wasPaidBefore = PlanService.shared.isPaid
                await PlanService.shared.refresh()
                if !wasPaidBefore, PlanService.shared.isPaid, !recordingService.isRecording {
                    await TranscriptionCoordinator.shared.prepare()
                }
            }

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
            guard let saved = saved else { return }
            recoveredURL = saved.url
            recoveredDuration = saved.duration
            recoveredTitle = saved.title
            isMaxDurationStop = recordingService.stoppedAtMaxDuration
            recordingService.stoppedAtMaxDuration = false
            recordingService.unexpectedlySavedRecording = nil
            showRecoverySheet = true
        }
    }

    // MARK: - Account Chip

    @ViewBuilder
    private var accountChip: some View {
        if authService.isAuthenticated, let email = authService.currentUser?.email {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text(email)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.06))
            .clipShape(Capsule())
        } else {
            Button {
                showLoginSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 13))
                    Text("Sign In")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.08))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Org Banner

    private var orgBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue)
            Text(orgService.currentOrganization?.name ?? "")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(.primary)
            Text("•")
                .foregroundColor(.secondary.opacity(0.4))
            Text(orgService.currentRole?.displayName ?? "")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Group {
            if recordingService.isRecording {
                LinearGradient(
                    colors: recordingService.isPaused
                        ? [Color.orange.opacity(0.06), Color(.systemBackground)]
                        : [Color.red.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .animation(.easeInOut(duration: 0.6), value: recordingService.isPaused)
            } else {
                LinearGradient(
                    colors: [Color.blue.opacity(0.04), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
    }

    // MARK: - Subviews

    private var timerDisplay: some View {
        Text(formatDuration(recordingService.recordingDuration))
            .font(.system(size: isIPad ? 72 : 58, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundColor(recordingService.isRecording
                ? (recordingService.isPaused ? .orange : .primary)
                : .secondary.opacity(0.4))
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.15), value: recordingService.recordingDuration)
            .accessibilityLabel("Recording duration: \(formatDuration(recordingService.recordingDuration))")
    }

    @ViewBuilder
    private var waveformDisplay: some View {
        if recordingService.isRecording {
            AudioWaveformView(levels: recordingService.audioLevelHistory)
                .opacity(recordingService.isPaused ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: recordingService.isPaused)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Group {
            if recordingService.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(recordingService.isPaused ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(recordingService.isPaused ? 0.5 : recordingDotOpacity)

                    Text(recordingService.isPaused ? "PAUSED" : "REC")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(recordingService.isPaused ? .orange : .red)
                        .kerning(1.5)

                    Text("\u{2022}")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.3))

                    Text(estimatedFileSize(recordingService.recordingDuration))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(recordingService.isPaused
                            ? Color.orange.opacity(0.08)
                            : Color.red.opacity(0.08))
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        recordingDotOpacity = 0.2
                    }
                }
                .onDisappear {
                    recordingDotOpacity = 1.0
                }
            } else if liveCoordinator.isPreparing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Preparing transcription…")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(.blue)
                        .kerning(0.5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.08))
                )
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var maxDurationWarning: some View {
        if recordingService.showMaxDurationWarning && recordingService.isRecording {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Auto-stop in \(formatCountdown(recordingService.remainingSecondsBeforeAutoStop))")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.1))
            .clipShape(Capsule())
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    @ViewBuilder
    private var lowAudioWarning: some View {
        if showLowAudioWarning && recordingService.isRecording && !recordingService.isPaused {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("Audio level low \u{2014} move closer to speaker")
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.08))
            .clipShape(Capsule())
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private var bookmarkToast: some View {
        if showBookmarkToast {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.caption2)
                Text("Bookmarked!")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .clipShape(Capsule())
            .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    private var controlButtons: some View {
        HStack(spacing: isIPad ? 36 : 28) {
            if recordingService.isRecording {
                // Pause/Resume
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
                            .fill(Color.orange)
                            .frame(width: isIPad ? 64 : 52, height: isIPad ? 64 : 52)
                        Image(systemName: recordingService.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: isIPad ? 22 : 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }
                .accessibilityLabel(recordingService.isPaused ? "Resume recording" : "Pause recording")
                .transition(.scale.combined(with: .opacity))
            }

            // Main record/stop button
            Button(action: {
                if liveCoordinator.isPreparing { return } // 準備中は二重起動防止
                if recordingService.isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                ZStack {
                    // Outer pulse ring (recording only)
                    if recordingService.isRecording && !recordingService.isPaused {
                        Circle()
                            .stroke(Color.red.opacity(0.2), lineWidth: 2)
                            .frame(width: isIPad ? 110 : 86, height: isIPad ? 110 : 86)
                            .scaleEffect(ringPulse ? 1.15 : 1.0)
                            .opacity(ringPulse ? 0 : 0.6)
                    }

                    // Outer ring
                    Circle()
                        .stroke(
                            recordingService.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.15),
                            lineWidth: 3
                        )
                        .frame(width: isIPad ? 100 : 80, height: isIPad ? 100 : 80)

                    // Main button
                    Circle()
                        .fill(recordingService.isRecording ? Color.red : (liveCoordinator.isPreparing ? Color.blue.opacity(0.6) : Color.blue))
                        .frame(width: isIPad ? 80 : 64, height: isIPad ? 80 : 64)

                    // Icon
                    Group {
                        if liveCoordinator.isPreparing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(isIPad ? 1.3 : 1.1)
                        } else if recordingService.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: isIPad ? 24 : 20, height: isIPad ? 24 : 20)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: isIPad ? 28 : 22))
                                .foregroundColor(.white)
                        }
                    }
                }
                .shadow(color: recordingService.isRecording ? .red.opacity(0.25) : .blue.opacity(0.25), radius: 12, y: 6)
            }
            .accessibilityLabel(recordingService.isRecording ? "Stop recording" : "Start recording")

            if recordingService.isRecording {
                // Bookmark
                Button(action: addBookmark) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: isIPad ? 64 : 52, height: isIPad ? 64 : 52)
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: isIPad ? 22 : 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 4)
                }
                .accessibilityLabel("Add bookmark")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: recordingService.isRecording)
    }

    @ViewBuilder
    private var bookmarkCount: some View {
        if recordingService.isRecording && !pendingBookmarks.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 9))
                Text("\(pendingBookmarks.count)")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
            .foregroundColor(.accentColor.opacity(0.7))
        }
    }

    @ViewBuilder
    private var idleHint: some View {
        if !recordingService.isRecording {
            VStack(spacing: 10) {
                Text("Tap to start recording")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))

                Button {
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text(currentLanguageDisplay)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(Capsule())
                }

                if !transcriptionService.isModelLoaded {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Preparing AI model...")
                            .font(.system(.caption2, design: .rounded))
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showBookmarkToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
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
            if !hasAcceptedAIConsent {
                showAIConsentSheet = true
                return
            }

            // B2B gate: org members must stamp FERPA consent before the first
            // recording. Non-org users (B2C) are unaffected — the service's
            // shouldPromptConsent stays false when activeOrgId is nil.
            if ferpaConsent.shouldPromptConsent {
                return
            }

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

            // Pro (org member): Deepgram websocket 接続を並行で投げる。await しないので
            // ユーザーはボタンを押した瞬間に録音が始まる。字幕は接続完了後に追いついて
            // 流れ始める（この間の音声は m4a には確実に入る → 抜け落ちない）。
            // 接続失敗時も録音自体は続行し、録音後 WhisperKit fallback で文字起こしされる。
            if PlanService.shared.isPaid {
                Task { @MainActor in await liveCoordinator.prepare() }
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

    private func saveLecture(title: String, courseName: String?, classId: UUID?) async {
        guard let audioURL = pendingAudioURL else { return }

        // Live字幕で文字起こし済みなら、Deepgramの結果をそのまま採用してWhisperKit処理を省略
        // consume は内部で Deepgram の flush (最大1.5s) を待つので、停止直後に保存しても欠けない
        let liveResult = await liveCoordinator.consumeFinalizedTranscript()

        // B2B: thread the selected class through OrganizationContext so the
        // cloud-sync call emits class_id (and visibility='class') on the
        // Supabase transcript row. Org admins' usage dashboard aggregates on
        // this. Context is sticky: the next recording inherits this class
        // until the user picks a different one in TitleInputSheet — matches
        // the natural "I'm in Math 101 today" UX.
        if OrganizationContext.shared.activeOrgId != nil {
            OrganizationContext.shared.classId = classId?.uuidString
            OrganizationContext.shared.visibility = classId != nil ? .class : .private_
        }

        var lecture = Lecture(
            title: title,
            createdAt: Date(),
            duration: pendingDuration,
            audioPath: audioURL,
            transcriptStatus: liveResult != nil ? .completed : .notStarted,
            language: transcriptionService.transcriptionLanguage,
            bookmarks: pendingBookmarks,
            courseName: courseName
        )

        if let live = liveResult {
            lecture.transcriptText = live.text
            lecture.transcriptSegments = live.segments
        }

        let store = LectureStore.shared
        store.addLecture(lecture)

        pendingAudioURL = nil
        pendingDuration = 0
        pendingBookmarks = []

        NotificationCenter.default.post(name: .lectureRecordingCompleted, object: nil)

        // Live結果が無いときだけWhisperKit fallback
        if liveResult == nil {
            Task {
                await startTranscription(for: lecture)
            }
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

        // Primary: Deepgram Prerecorded（有料プラン + オンライン + 認証済の時のみ）
        // Free プランは WhisperKit にフォールバック（= 旧フロー完全復元）
        if AuthService.shared.isAuthenticated && PlanService.shared.isPaid {
            do {
                let dgResult = try await DeepgramBatchService.shared.transcribe(
                    audioURL: audioURL,
                    language: transcriptionService.transcriptionLanguage.deepgramCode
                )
                guard var latest = store.getLecture(by: lectureId) else { return }
                latest.transcriptText = dgResult.text
                latest.transcriptSegments = dgResult.segments
                latest.transcriptStatus = .completed
                if let lang = dgResult.language {
                    // Deepgramが検出した言語が既存設定と違っても、設定は触らない（UIから手動変更可）
                    AppLogger.info("Deepgram detected language: \(lang)", category: .transcription)
                }
                store.updateLecture(latest)

                Task {
                    await CloudSyncService.shared.uploadTranscriptIfEnabled(
                        clientId: latest.id,
                        title: latest.title,
                        content: dgResult.text,
                        createdAt: latest.createdAt,
                        durationSeconds: latest.duration,
                        language: transcriptionService.transcriptionLanguage.rawValue
                    )
                }
                return
            } catch {
                AppLogger.warning("Deepgram batch failed (\(error.localizedDescription)) — falling back to WhisperKit", category: .transcription)
                // continue to WhisperKit fallback below
            }
        }

        // Fallback: WhisperKit (offline or Deepgram失敗時)
        transcriptionService.onChunkCompleted = { partialText, partialSegments in
            guard var latest = store.getLecture(by: lectureId) else { return }
            latest.transcriptText = partialText
            latest.transcriptSegments = partialSegments
            store.updateLecture(latest)
        }

        do {
            let result = try await transcriptionService.transcribe(audioURL: audioURL, lectureId: lectureId)

            transcriptionService.onChunkCompleted = nil
            guard var latest = store.getLecture(by: lectureId) else { return }
            latest.transcriptText = result.text
            latest.transcriptSegments = result.segments
            latest.transcriptStatus = .completed
            latest.language = transcriptionService.transcriptionLanguage
            store.updateLecture(latest)

            // Cloud sync (fire-and-forget): upload the transcript text — NOT
            // the audio file — to Supabase so school admins can see activity
            // and users don't lose notes when their phone breaks. Gated by
            // CloudSyncService (default ON, opt-out per device, signed-in only).
            // See doc/STRATEGIC_REVIEW_2026Q2.md for the strategic rationale.
            Task {
                await CloudSyncService.shared.uploadTranscriptIfEnabled(
                    clientId: latest.id,
                    title: latest.title,
                    content: result.text,
                    createdAt: latest.createdAt,
                    durationSeconds: latest.duration,
                    language: transcriptionService.transcriptionLanguage.rawValue
                )
            }
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
    let isMaxDuration: Bool
    let onSave: (String, String?) -> Void
    let onDiscard: () -> Void

    init(duration: TimeInterval, defaultTitle: String, isMaxDuration: Bool = false, onSave: @escaping (String, String?) -> Void, onDiscard: @escaping () -> Void) {
        self.duration = duration
        self.isMaxDuration = isMaxDuration
        _title = State(initialValue: defaultTitle)
        self.onSave = onSave
        self.onDiscard = onDiscard
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: isMaxDuration ? "clock.badge.checkmark" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isMaxDuration ? .blue : .orange)
                    .padding(.top, 24)

                Text(isMaxDuration ? "Maximum Length Reached" : "Recording Recovered")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text(isMaxDuration
                     ? "Recording reached the maximum length of \(formatDuration(duration)). Your audio has been saved."
                     : "A previous recording was interrupted. We saved \(formatDuration(duration)) of audio.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    TextField("Lecture title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)

                    TextField("Subject (optional)", text: $courseName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)
                }
                .padding(.horizontal, 24)

                Button(action: save) {
                    Text("Save Recording")
                        .font(.system(.headline, design: .rounded))
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
