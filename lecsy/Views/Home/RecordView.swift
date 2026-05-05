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
    // PlanService を @StateObject で観測する。LiveCaptionView の表示 gate に
    // `planService.isPaid` を使うため、refresh 直後に Pro になっても即 UI 反映される。
    @StateObject private var planService = PlanService.shared
    // Free 用 on-device 認識の feedback 表示に使う。Pro 経路では
    // start() が即 return するので published 値は静止する (副作用なし)。
    @StateObject private var whisperDecoder = WhisperLiveDecoder.shared
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
    @State private var pendingStartedAt: Date?
    /// Free 高速化: stop した瞬間に Lecture を仮作成 + transcription を起動して
    /// TitleSheet 入力時間を transcribe 時間に重ねる。set されている時は
    /// saveLecture を rename のみに切替える。Pro 経路は既存通り (Deepgram の
    /// consumeFinalizedTranscript を待ってから addLecture したいので nil)。
    @State private var pendingLectureId: UUID?
    @State private var lowAudioSeconds: Int = 0
    @State private var showLowAudioWarning = false
    @State private var recordingDotOpacity: Double = 1.0
    @State private var lastFailedLectureId: UUID?
    @State private var showLanguagePicker = false
    @State private var showRecoverySheet = false
    @State private var recoveredURL: URL?
    @State private var recoveredDuration: TimeInterval = 0
    @State private var recoveredTitle: String = ""
    @State private var recoveredStartedAt: Date?
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

                // 中央: リアルタイム字幕。Pro ユーザーが録音を始めた瞬間から
                // 必ず描画する。coordinator の isPreparing / isStartingLive を
                // 条件に含めるやり方だと、observeRecording が Task 経由で
                // isStartingLive=true を立てるまでに数十ms の空白が生まれ、
                // 「最初出てなくて後から出てくる」ように見えていた。
                // 表示の有無は "録音中かつ Pro" の2条件だけで決め、Connecting /
                // Listening / Live の区別は LiveCaptionView の内部 phase に任せる。
                if recordingService.isRecording && planService.isPaid {
                    LiveCaptionView(coordinator: liveCoordinator)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if recordingService.isRecording && !planService.isPaid {
                    // Free 経路: WhisperKit が裏で 15s ごとに decode しているが
                    // 字幕は Pro と差別化するため出さない。代わりに「on-device で
                    // 認識が動いている実感」を出すことで、90 分録ったあと「何も
                    // 入ってない」不安を消す。`last heard:` は最後に決着した
                    // chunk のテキストで、real-time ではなく 15-22s 遅延で更新される。
                    FreeCaptureFeedback(decoder: whisperDecoder)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // オフラインバナー (Pro のみ)。Free は WhisperKit on-device だから
                // 完全にオフラインで動く → このバナーを出すと「文字起こしされない?」
                // と誤解する。Pro は Deepgram cloud に依存するので意味がある。
                if !liveCoordinator.isOnline && planService.isPaid {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Offline — recording saves locally")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale))
                }

                // 再接続中バナー（ネット断・電話・background 復帰などで session 張り直し中）
                if recordingService.isRecording && liveCoordinator.isReconnectingLive {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Reconnecting live captions…")
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

                // Main control buttons
                controlButtons
                    .padding(.bottom, 12)

                // Idle hint
                idleHint

                // Transcription in-progress hint (RecordView から save した直後、
                // ユーザーが録音画面に居続ける場合のカバー。LibraryView の banner
                // と同じ意図 — 別 app 切替で pause することを 1 行で伝える)。
                if !recordingService.isRecording &&
                   LectureStore.shared.lectures.contains(where: { $0.transcriptStatus == .processing }) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        Text("Transcribing — keep Lecsy open. Switching apps pauses progress.")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(.primary.opacity(0.85))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 12)
                }

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
            TitleInputSheet(defaultTitle: defaultRecordingTitle(for: pendingStartedAt)) { title, courseName, classId in
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
                        recoveredStartedAt = recovered.startedAt
                        recoveredTitle = recovered.title.isEmpty ? defaultRecordingTitle(for: recovered.startedAt) : recovered.title
                        showRecoverySheet = true
                    }
                }
            }
        }
        .onChange(of: recordingService.unexpectedlySavedRecording) { _, saved in
            guard let saved = saved else { return }
            recoveredURL = saved.url
            recoveredDuration = saved.duration
            recoveredStartedAt = saved.startedAt
            recoveredTitle = saved.title.isEmpty ? defaultRecordingTitle(for: saved.startedAt) : saved.title
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
            } else if !planService.isPaid && transcriptionService.downloadElapsedSeconds > 0 && !transcriptionService.downloadStatusText.isEmpty {
                // Free 用: WhisperKit cold-load (CoreML JIT compile で 80-130s)
                // 中の状態が録音前の idle 画面で完全に静止していた。Pro の
                // `liveCoordinator.isPreparing` 経路には乗らないので、Free user は
                // 「アプリ動いてる?」状態のまま録音ボタンを連打してしまう。
                // downloadStatusText / downloadElapsedSeconds は TranscriptionService
                // が既に published しているのでそのまま流す。
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(transcriptionService.downloadStatusText)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        if !UserDefaults.standard.bool(forKey: "lecsy.hasCompletedFirstModelLoad") {
                            Text("First-time setup • \(transcriptionService.downloadElapsedSeconds)s")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
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
        // Pro 利用者は LiveCaptionView 内の MOVE CLOSER ピルで同等のガイダンスを
        // 受けるため、ここの帯と二重表示になる。Free 利用者は LiveCaptionView を
        // 出していない (planService.isPaid gate) ので、この帯が唯一の低音量警告。
        if showLowAudioWarning
            && recordingService.isRecording
            && !recordingService.isPaused
            && !planService.isPaid {
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
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: recordingService.isRecording)
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
            }
        }
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Recording Actions

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
            // Sentry filter 用 flow tag。録音→停止→post-recording transcribe path 中の
            // error を Issue 一覧で `flow:live-recording` で絞れる。
            AppLogger.setSentryTag("flow", value: "live-recording")
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
            } catch {
                recordingError = ErrorMessages.forRecording(error)
                showRecordingErrorAlert = true
            }
        }
    }

    private func stopRecording() {
        pendingDuration = recordingService.recordingDuration
        // Capture before stopRecording() — RecordingService nils recordingStartTime on stop.
        // createdAt must equal the recording's start instant so Library sort matches the title.
        pendingStartedAt = recordingService.recordingStartTime
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

        // Free fast path: stop した瞬間に Lecture を仮作成 + startTranscription を
        // 起動する。TitleSheet 入力時間 (5-15s) が transcribe 時間に重なって
        // 体感の「stop → progress 表示」が ~5s に縮まる。
        //
        // - Lecture.id は録音開始時に RecordingService が発行した UUID を使う
        //   (WhisperLiveDecoder の chunkCache がこの ID で育っているため)。
        // - default title (e.g. "Lecture Apr 30, 2026 14:32") で先に addLecture。
        //   TitleSheet 確定時は saveLecture が pendingLectureId を見て rename
        //   のみ実行する (二重 add を防ぐ)。
        // - drain も別途 detached で走らせる (既存挙動)。
        //
        // Pro 経路はこの fast path に乗らない: Deepgram live の最終 flush を
        // consumeFinalizedTranscript で吸い上げてから Lecture を作る必要があり、
        // 仮 Lecture に後から live 結果を merge する複雑性を避けたい。
        if !PlanService.shared.isPaid {
            Task.detached {
                await WhisperLiveDecoder.shared.awaitDrain(timeout: 30)
            }

            let consumedId = recordingService.consumeRecordingId() ?? UUID()
            // .processing で初期化: Library row が一瞬「Not transcribed」と
            // 表示されるフリッカーを避ける (startTranscription が flip する前に
            // 描画されるパスがある)。
            let placeholder = Lecture(
                id: consumedId,
                title: defaultRecordingTitle(for: pendingStartedAt),
                createdAt: pendingStartedAt ?? Date(),
                duration: pendingDuration,
                audioPath: audioURL,
                transcriptStatus: .processing,
                language: transcriptionService.transcriptionLanguage,
                bookmarks: [],
                courseName: nil,
                lowAudioSeconds: recordingService.cumulativeLowAudioSeconds
            )
            pendingLectureId = consumedId
            LectureStore.shared.addLecture(placeholder)
            NotificationCenter.default.post(name: .lectureRecordingCompleted, object: nil)

            Task {
                await startTranscription(for: placeholder)
            }
        }

        showTitleSheet = true
    }

    private func saveLecture(title: String, courseName: String?, classId: UUID?) async {
        // FREE FAST-PATH: stop 時点で Lecture 作成 + transcription 起動済。
        // ここでは title/courseName/classId の rename と OrgContext 更新だけ。
        if let lectureId = pendingLectureId {
            if OrganizationContext.shared.activeOrgId != nil {
                OrganizationContext.shared.classId = classId?.uuidString
                OrganizationContext.shared.visibility = classId != nil ? .class : .private_
            }
            if var existing = LectureStore.shared.getLecture(by: lectureId) {
                existing.title = title
                existing.courseName = courseName
                LectureStore.shared.updateLecture(existing)
            }
            pendingLectureId = nil
            pendingAudioURL = nil
            pendingDuration = 0
            pendingStartedAt = nil
            return
        }

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

        // 録音開始時に RecordingService が生成した UUID を Lecture.id に流用する。
        // Free プランの WhisperLiveDecoder が同じ ID で chunkCache を育てているので、
        // post-stop の startTranscription が cache を引き上げられる。
        // Pro / Deepgram live 経路では cache は空なので素通り。
        let consumedId = recordingService.consumeRecordingId() ?? UUID()

        var lecture = Lecture(
            id: consumedId,
            title: title,
            createdAt: pendingStartedAt ?? Date(),
            duration: pendingDuration,
            audioPath: audioURL,
            transcriptStatus: liveResult != nil ? .completed : .notStarted,
            language: transcriptionService.transcriptionLanguage,
            bookmarks: [],
            courseName: courseName,
            lowAudioSeconds: recordingService.cumulativeLowAudioSeconds
        )

        if let live = liveResult {
            lecture.transcriptText = live.text
            lecture.transcriptSegments = live.segments
        }

        let store = LectureStore.shared
        store.addLecture(lecture)

        pendingAudioURL = nil
        pendingDuration = 0
        pendingStartedAt = nil

        NotificationCenter.default.post(name: .lectureRecordingCompleted, object: nil)

        if let live = liveResult {
            // Deepgram Live 経路: Pro ユーザーの B2B 動線。transcript text だけ (audio は上げない)
            // を Supabase に送って org 管理画面の Recent Activity / Usage に反映させる。
            // 以前のコードではこのブランチで upload 呼び出しが欠けており、Pro ユーザーの
            // 通常録音がダッシュボードに一切流れていなかった。
            let savedLecture = lecture
            let langRaw = transcriptionService.transcriptionLanguage.rawValue
            let liveText = live.text
            Task {
                await CloudSyncService.shared.uploadTranscriptIfEnabled(
                    clientId: savedLecture.id,
                    title: savedLecture.title,
                    content: liveText,
                    createdAt: savedLecture.createdAt,
                    durationSeconds: savedLecture.duration,
                    language: langRaw
                )
            }
        } else {
            // Live 結果が無い場合 (Deepgram 失敗 / Free プラン / 権限 off) は WhisperKit fallback。
            // WhisperKit の結果は cloud には送らず local only (プライバシーモデルの核心)。
            Task {
                await startTranscription(for: lecture)
            }
        }
    }

    private func saveRecoveredLecture(title: String, courseName: String?) {
        guard let audioURL = recoveredURL else { return }

        let lecture = Lecture(
            title: title,
            createdAt: recoveredStartedAt ?? Date(),
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
        recoveredStartedAt = nil

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
        recoveredStartedAt = nil
    }

    private func defaultRecordingTitle(for date: Date? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        let anchor = date ?? recordingService.recordingStartTime ?? Date()
        return "Lecture \(formatter.string(from: anchor))"
    }

    private func startTranscription(for lecture: Lecture) async {
        guard let audioURL = lecture.audioPath else { return }

        let lectureId = lecture.id
        let store = LectureStore.shared

        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        store.updateLecture(updatedLecture)

        let progress = TranscriptionProgressService.shared
        progress.set(.preparing, for: lectureId)
        // placeholder bar を即時表示。LectureDetailView は index=0 の時
        // indeterminate な linear ProgressView を出すので、cold-load 80s 中も
        // 「動いてる」アニメが続く。chunked loop の最初の実 progress (index=1)
        // が来た瞬間に startedAt が reset され、ETA が正しく計算される。
        // 推定 chunk 数は 30s 窓で割った天井 (実際は VAD で前後するが、UI 用途
        // の placeholder としては十分)。
        let estimatedChunks = max(1, Int((lecture.duration / 30.0).rounded(.up)))
        progress.setChunkProgress(0, of: estimatedChunks, for: lectureId)
        defer {
            progress.clear(for: lectureId)
            // Free 経路で transcribing phase に切り替えた Live Activity を done →
            // 短時間表示 → end する。Pro 経路は stopRecording 時に既に end 済み
            // で、この呼び出しは no-op になる。
            RecordingService.shared.finishLiveActivityWithDone()
        }

        // Free 用 live decoder の最速化:
        //
        // OPTIMISTIC COMPLETION: 既 decode 済 chunks (95%+ coverage) を見つけた
        // 瞬間に .completed mark + 即時 return。残りの tail decode は detached
        // Task で背景処理し、完了時に transcript を silently 上書きする。
        //
        // ユーザー体感: post-stop wait = ~0s (Save 直後に completed 表示)。
        // 残り 2-5% の tail は 5-15s 後に背景で追記される (status は .completed
        // のまま、transcript text/segments だけ extend される)。
        //
        // Pro 経路は通らない (二重 !isPaid gate)。
        if !PlanService.shared.isPaid {
            let earlyChunks = transcriptionService.loadLiveDecodedChunks(lectureId: lectureId)
            let earlyMaxEnd = earlyChunks.map(\.end).max() ?? 0

            // 既 decode 分を即時 lecture に貼る (status はまだ .processing)
            if !earlyChunks.isEmpty {
                let earlyStitched = transcriptionService.stitchLiveCachedChunks(earlyChunks)
                if var latest = store.getLecture(by: lectureId) {
                    latest.transcriptText = earlyStitched.text
                    latest.transcriptSegments = earlyStitched.segments
                    store.updateLecture(latest)
                }
                AppLogger.info("Early partial display: \(earlyChunks.count) chunks (\(Int(earlyMaxEnd))/\(Int(lecture.duration))s) — drain runs in background", category: .transcription)
            }

            // OPTIMISTIC GATE: 既 decode 分が録音時間の 70% 以上を覆ってて、
            // gap も無いなら即時 .completed。残りは detached で追記。
            // 70% は控えめ閾値 (45s/15s chunk 構成で「直前 1-2 chunks 残ってる」
            // 状況をカバーする)。
            let earlyCompletion = transcriptionService.liveCacheCompletion(
                lectureId: lectureId,
                totalDuration: lecture.duration
            )
            let optimisticReady = !earlyChunks.isEmpty
                && earlyCompletion.gapCount == 0
                && earlyMaxEnd >= max(lecture.duration - 60, lecture.duration * 0.70)

            if optimisticReady {
                // 1) Optimistic complete: 今ある分で .completed mark
                if var latest = store.getLecture(by: lectureId) {
                    latest.transcriptStatus = .completed
                    latest.language = transcriptionService.transcriptionLanguage
                    store.updateLecture(latest)
                }
                AppLogger.info("Optimistic complete: marked .completed at coverage \(Int(earlyMaxEnd))/\(Int(lecture.duration))s — tail will be appended in background", category: .transcription)

                // 2) 残り tail を detached で drain → 完了したら silently 上書き
                Task.detached {
                    await WhisperLiveDecoder.shared.awaitDrain(timeout: 30)
                    await MainActor.run {
                        let svc = TranscriptionService.shared
                        let finalChunks = svc.loadLiveDecodedChunks(lectureId: lectureId)
                        guard !finalChunks.isEmpty else { return }
                        let finalStitched = svc.stitchLiveCachedChunks(finalChunks)
                        if var latest = LectureStore.shared.getLecture(by: lectureId) {
                            // 既に optimistic mark で .completed なので status はそのまま。
                            // text / segments だけ最終版で上書き。
                            latest.transcriptText = finalStitched.text
                            latest.transcriptSegments = finalStitched.segments
                            LectureStore.shared.updateLecture(latest)
                        }
                        svc.clearChunkCache(lectureId: lectureId)
                        AppLogger.info("Background tail update: extended transcript to \(finalChunks.count) chunks", category: .transcription)
                    }
                }
                return
            }

            // OPTIMISTIC NOT READY (cache 不完全 / gap あり) → drain 待って判定
            if WhisperLiveDecoder.shared.pendingChunks > 0 || WhisperLiveDecoder.shared.isActive {
                progress.set(.finalizingLive, for: lectureId)
            }
            await WhisperLiveDecoder.shared.awaitDrain(timeout: 30)
            progress.set(.transcribing, for: lectureId)

            let completion = transcriptionService.liveCacheCompletion(
                lectureId: lectureId,
                totalDuration: lecture.duration
            )
            if completion.isComplete {
                let stitched = transcriptionService.stitchLiveCachedChunks(completion.chunks)
                guard var latest = store.getLecture(by: lectureId) else { return }
                latest.transcriptText = stitched.text
                latest.transcriptSegments = stitched.segments
                latest.transcriptStatus = .completed
                latest.language = transcriptionService.transcriptionLanguage
                store.updateLecture(latest)
                transcriptionService.clearChunkCache(lectureId: lectureId)
                AppLogger.info("Transcription completed via live cache (\(completion.chunks.count) chunks, coverage \(Int(completion.coverage))/\(Int(lecture.duration))s)", category: .transcription)
                return
            } else if !completion.chunks.isEmpty {
                AppLogger.info("Live cache incomplete (coverage \(Int(completion.coverage))/\(Int(lecture.duration))s, gaps=\(completion.gapCount)) — falling back to chunked path", category: .transcription)
            }
        }

        // 以降は cache 不完全 / Pro / その他全部の post-stop fallback。
        // enhance の判断:
        //  - Free は per-chunk preprocessing を live decoder が担うのが原則だが、
        //    cold start で model load 中に録音 stop した時は live decoder が走らず
        //    raw audio が chunked path に流れる。それでも post-stop で 65s ファイル
        //    全体に enhance をかけると 3-5s 待たされて UX が悪い。Whisper は
        //    -28dBFS 程度なら decode できるので、ここは speed を取って skip。
        //    accuracy が必要な場合は LectureDetailView の retranscribe で再走可能。
        //  - Pro はそのまま enhance (Deepgram 失敗 → WhisperKit fallback の
        //    最終手段なので品質を最優先)。
        var transcribeURL = audioURL
        var enhancedURL: URL?
        let isFree = !PlanService.shared.isPaid
        if isFree {
            AppLogger.info("Skipping enhance: free path — chunked decoder handles low volume", category: .transcription)
        } else if let peakDB = try? await AudioEnhancementService.shared.peakDBFS(audioURL: audioURL),
                  peakDB.isFinite, peakDB < -10 {
            AppLogger.info("Initial transcription: peak \(String(format: "%.1f", peakDB))dBFS < -10, enhancing", category: .transcription)
            progress.set(.normalizing, for: lectureId)
            if let e = try? await AudioEnhancementService.shared.enhance(audioURL: audioURL) {
                enhancedURL = e
                transcribeURL = e
            }
            progress.set(.transcribing, for: lectureId)
        }

        defer {
            if let e = enhancedURL {
                try? FileManager.default.removeItem(at: e)
            }
        }

        // Primary: Deepgram Prerecorded (Pro + オンライン + 認証済の時のみ)
        if AuthService.shared.isAuthenticated && PlanService.shared.isPaid {
            do {
                let dgResult = try await DeepgramBatchService.shared.transcribe(
                    audioURL: transcribeURL,
                    language: transcriptionService.transcriptionLanguage.deepgramCode
                )
                guard var latest = store.getLecture(by: lectureId) else { return }
                latest.transcriptText = dgResult.text
                latest.transcriptSegments = dgResult.segments
                latest.transcriptStatus = .completed
                if let lang = dgResult.language {
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
            }
        }

        // WhisperKit chunked path with **auto-retry** (transient failure 耐性)。
        // 失敗の典型: GPU 競合 / thermal throttle / メモリ瞬間圧迫。再試行で
        // ほぼ確実に通る。chunked path 内で cachedSegments を resume として
        // 拾うので、前回の試行で decode 済み chunk は重複処理しない。
        let outcome = await runChunkedWithRetry(
            audioURL: transcribeURL,
            lectureId: lectureId,
            maxAttempts: 3
        )
        switch outcome {
        case .success(let result):
            guard var latest = store.getLecture(by: lectureId) else { return }
            latest.transcriptText = result.text
            latest.transcriptSegments = result.segments
            latest.transcriptStatus = .completed
            latest.language = transcriptionService.transcriptionLanguage
            store.updateLecture(latest)
        case .failure(let error):
            // 全 attempt 失敗 → cache に拾えるだけ拾って partial で残す。
            // 完全 stitch じゃなくても、覆われた範囲は読めるのでユーザーに 0 を返さない。
            let partial = transcriptionService.loadLiveDecodedChunks(lectureId: lectureId)
            if !partial.isEmpty {
                let stitched = transcriptionService.stitchLiveCachedChunks(partial)
                if var latest = store.getLecture(by: lectureId) {
                    latest.transcriptText = stitched.text
                    latest.transcriptSegments = stitched.segments
                    latest.transcriptStatus = .failed // partial 状態で .failed → user が retry できる
                    store.updateLecture(latest)
                }
                AppLogger.warning("Transcription failed after retries — saved partial cache (\(partial.count) chunks)", category: .transcription)
            } else if var latest = store.getLecture(by: lectureId) {
                latest.transcriptStatus = .failed
                store.updateLecture(latest)
            }

            if let tx = error as? TranscriptionError, case .audioFileTooShort = tx {
                AppLogger.debug("Transcription skipped (audio too short)", category: .recording)
            } else {
                AppLogger.error("Transcription failed after retries: \(error)", category: .recording)
            }

            await MainActor.run {
                lastFailedLectureId = lecture.id
                transcriptionError = ErrorMessages.forTranscription(error)
                showTranscriptionErrorAlert = true
            }
        }
    }

    private enum ChunkedOutcome {
        case success(TranscriptionResult)
        case failure(Error)
    }

    /// chunked transcribe を最大 maxAttempts 回までリトライ。`audioFileTooShort`
    /// 等の永続エラーは即 abort。timeout / GPU 競合 / メモリ圧迫等の transient
    /// は backoff してリトライ。chunked path 自体に cachedSegments の resume が
    /// あるので、リトライ時は決着済 chunk を再 decode しない。
    private func runChunkedWithRetry(
        audioURL: URL,
        lectureId: UUID,
        maxAttempts: Int
    ) async -> ChunkedOutcome {
        var workingURL = audioURL
        var repairedURL: URL?
        var didAttemptRepair = false
        defer {
            if let r = repairedURL {
                try? FileManager.default.removeItem(at: r)
            }
        }

        var lastError: Error?
        for attempt in 1...maxAttempts {
            transcriptionService.onChunkCompleted = { partialText, partialSegments in
                guard var latest = LectureStore.shared.getLecture(by: lectureId) else { return }
                latest.transcriptText = partialText
                latest.transcriptSegments = partialSegments
                LectureStore.shared.updateLecture(latest)
            }
            do {
                let result = try await transcriptionService.transcribe(audioURL: workingURL, lectureId: lectureId)
                transcriptionService.onChunkCompleted = nil
                if attempt > 1 {
                    AppLogger.info("Transcription succeeded on attempt \(attempt)/\(maxAttempts)", category: .transcription)
                }
                return .success(result)
            } catch {
                transcriptionService.onChunkCompleted = nil
                lastError = error

                // audioLoadFailed: moov atom 破損などで AVAudioFile が開けないケース。
                // AVAssetExportSession で再 mux すると ~80% は読めるようになる
                // (memory `feedback_audio_must_survive.md`)。1 度だけ試す。
                if !didAttemptRepair, let tx = error as? TranscriptionError, case .audioLoadFailed = tx {
                    didAttemptRepair = true
                    AppLogger.warning("Transcription got audioLoadFailed — attempting m4a re-mux repair", category: .transcription)
                    if let repaired = try? await AudioEnhancementService.shared.repair(audioURL: workingURL) {
                        repairedURL = repaired
                        workingURL = repaired
                        AppLogger.info("Audio repaired — retrying transcription on re-muxed file", category: .transcription)
                        // attempt counter を消費せず即時 retry
                        continue
                    } else {
                        AppLogger.warning("Audio repair failed — abandoning", category: .transcription)
                        return .failure(error)
                    }
                }

                // 永続エラーは retry しない
                if isPermanentTranscriptionError(error) {
                    return .failure(error)
                }
                if attempt < maxAttempts {
                    let backoffSeconds = Double(attempt) * 2.0
                    AppLogger.warning("Transcription attempt \(attempt)/\(maxAttempts) failed (\(error.localizedDescription)) — retrying in \(Int(backoffSeconds))s", category: .transcription)
                    try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                }
            }
        }
        return .failure(lastError ?? TranscriptionError.transcriptionFailed)
    }

    /// retry しても直らないエラーを判定。これらは即 abort。
    /// audioLoadFailed は permanent から外した: m4a の moov atom 破損で 1 度だけ
    /// 開けないケースは AVAssetExportSession の re-mux で復活する事が多い。
    /// runChunkedWithRetry が `repair → 再試行` を 1 回だけ行うようにした。
    /// memory `feedback_audio_must_survive.md`「m4a 再生不能は障害扱い」と整合。
    private func isPermanentTranscriptionError(_ error: Error) -> Bool {
        if let tx = error as? TranscriptionError {
            switch tx {
            case .audioFileNotFound, .audioFileTooShort, .modelNotLoaded:
                return true
            default:
                return false
            }
        }
        return false
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
