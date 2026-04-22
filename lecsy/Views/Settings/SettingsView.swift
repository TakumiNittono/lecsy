//
//  SettingsView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared
    @StateObject private var planService = PlanService.shared
    @ObservedObject private var recordingService = RecordingService.shared
    @State private var translationTarget: TranslationTargetLanguage = .current
    @AppStorage(PlanService.forceLocalKey) private var forceLocalTranscription: Bool = false

    @State private var showSignInSheet = false
    @State private var showSignOutDialog = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountErrorAlert = false
    @State private var deleteAccountErrorMessage = ""
    @State private var isDeletingAccount = false
    @State private var isSigningOut = false
    @State private var showReportSheet = false
    @State private var cloudSyncEnabled = CloudSyncService.shared.isEnabled
    @ObservedObject private var cloudSync = CloudSyncService.shared
    @State private var isOpeningPortal = false
    @State private var billingErrorMessage: String?

    var body: some View {
        NavigationView {
            List {
                // Transcription Language
                Section {
                    // Dropdown picker (Menu style) — single row instead of long list
                    Picker("Language", selection: Binding(
                        get: { transcriptionService.transcriptionLanguage },
                        // SwiftUI の view update 中に @Published を書き換えると
                        // "Publishing changes from within view updates" 警告が出るため
                        // 次の run loop にずらす
                        set: { newLang in
                            DispatchQueue.main.async {
                                transcriptionService.setLanguage(newLang)
                            }
                        }
                    )) {
                        ForEach(availableLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(recordingService.isRecording)

                    if recordingService.isRecording {
                        Text("Language can't be changed while recording")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Multilingual kit download / status
                    if transcriptionService.isDownloadingMultilingualKit {
                        // Downloading — show progress
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(transcriptionService.downloadStatusText)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatDownloadElapsed(transcriptionService.downloadElapsedSeconds))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            Text("Do not close the app during download")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.vertical, 4)
                    } else if !transcriptionService.isMultilingualKitInstalled {
                        // Not installed — show download button
                        Button {
                            Task {
                                await transcriptionService.downloadMultilingualKit()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 10) {
                                    Image(systemName: transcriptionService.multilingualKitDownloadFailed ? "exclamationmark.triangle.fill" : "globe")
                                        .font(.title3)
                                        .foregroundColor(transcriptionService.multilingualKitDownloadFailed ? .orange : .blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(transcriptionService.multilingualKitDownloadFailed ? "Retry Download" : "Add More Languages")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(transcriptionService.multilingualKitDownloadFailed ? .orange : .blue)
                                        Text("日本語, Español, Français, Deutsch and more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(transcriptionService.multilingualKitDownloadFailed ? .orange.opacity(0.6) : .blue.opacity(0.6))
                                }
                                Text(transcriptionService.multilingualKitDownloadFailed ? "Download failed — tap to retry (~460 MB)" : "~460 MB download")
                                    .font(.caption2)
                                    .foregroundColor(transcriptionService.multilingualKitDownloadFailed ? .orange.opacity(0.7) : .secondary.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Transcription Language")
                }

                // Transcription Method — Pro (org member) のみ override トグルを表示。
                // Free プランは常にオンデバイス (WhisperKit) 固定なので何も出さない。
                // 資格ベース(isProEntitled)で gate する。isPaid で gate すると、トグル ON で
                // isPaid=false になり、セクション自体が消えて OFF に戻せなくなる。
                if planService.isProEntitled {
                    Section {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("On-Device Only")
                                    .foregroundColor(.primary)
                                Text(forceLocalTranscription
                                     ? "Using on-device transcription"
                                     : "Using cloud transcription")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $forceLocalTranscription)
                                .labelsHidden()
                                .onChange(of: forceLocalTranscription) { _, _ in
                                    // objectWillChange.send を view update 中に呼ぶと
                                    // "Publishing changes from within view updates" 警告が出る
                                    DispatchQueue.main.async {
                                        planService.objectWillChange.send()
                                    }
                                }
                        }
                    } header: {
                        Text("Transcription Method")
                    } footer: {
                        Text("Force on-device processing. Turning this on disables real-time captions.")
                    }
                }

                // Bilingual Translation Target — Pro (org member) のみ表示
                if planService.isPaid {
                    Section {
                        Picker("Translate captions to", selection: $translationTarget) {
                            ForEach(TranslationTargetLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: translationTarget) { _, newValue in
                            TranslationTargetLanguage.set(newValue)
                        }
                    } header: {
                        Text("Bilingual Captions")
                    } footer: {
                        Text("Live captions show the original on the left and a translation in your chosen language on the right.")
                    }
                }


                // Account section
                Section("Account") {
                    if authService.isAuthenticated {
                        if let user = authService.currentUser {
                            HStack(spacing: 6) {
                                Text("Signed in as:")
                                Spacer()
                                Text(user.email ?? "Unknown")
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                // Quiet trial-period pill, placed next to the
                                // account email so it never collides with the
                                // status bar on iPad.
                                FreeCampaignBanner()
                            }
                        }

                        Button(action: {
                            if !isSigningOut { showSignOutDialog = true }
                        }) {
                            HStack {
                                if isSigningOut {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isSigningOut ? "Signing out…" : "Sign Out")
                            }
                        }
                        .foregroundColor(.red)
                        .disabled(isSigningOut)
                        .confirmationDialog(
                            "Sign Out?",
                            isPresented: $showSignOutDialog,
                            titleVisibility: .visible
                        ) {
                            Button("Sign Out", role: .destructive) {
                                Task { await performSignOut(wipeLocalData: false) }
                            }
                            Button("Sign Out & Delete Data on This Device", role: .destructive) {
                                Task { await performSignOut(wipeLocalData: true) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Choose whether to keep your local lectures on this device after signing out.")
                        }

                        Button(action: {
                            showDeleteAccountAlert = true
                        }) {
                            HStack {
                                if isDeletingAccount {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("Delete Account")
                            }
                        }
                        .foregroundColor(.red)
                        .disabled(isDeletingAccount)
                    } else {
                        HStack(spacing: 6) {
                            Button("Sign In") {
                                showSignInSheet = true
                            }
                            Spacer()
                            FreeCampaignBanner()
                        }
                    }
                }

                if authService.isAuthenticated {
                    PlanSection(
                        isOpeningPortal: isOpeningPortal,
                        openPortal: openPortal
                    )
                }

                // Support section
                Section("Support") {
                    Button {
                        showReportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.bubble")
                                .foregroundColor(.orange)
                            Text("Report a Problem")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Privacy section
                Section("Privacy") {
                    Toggle("Cloud Sync", isOn: $cloudSyncEnabled)
                        .onChange(of: cloudSyncEnabled) { _, newValue in
                            CloudSyncService.shared.setEnabled(newValue)
                        }
                    Text("Your transcript text is saved to Lecsy servers so you don't lose notes if your phone breaks. Audio files are NEVER uploaded — only the text. We do not use your data to train AI models.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Audio retention — on-device .m4a files の自動削除。transcript は残す
                    // ので「読み返せるが音声は聞けない」状態にすることでストレージ節約 +
                    // 端末紛失時の露出縮小。デフォルト .forever = 変化なし。
                    Picker("Delete audio after", selection: Binding(
                        get: { RecordingRetention.current },
                        set: { RecordingRetention.set($0) }
                    )) {
                        ForEach(RecordingRetention.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Text("Older audio files are removed from this device. Transcripts and summaries stay so you can still read them.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if authService.isAuthenticated && cloudSyncEnabled {
                        Button {
                            Task {
                                await CloudSyncService.shared.backfillAllLocalLectures(store: LectureStore.shared)
                            }
                        } label: {
                            HStack {
                                if cloudSync.isBackfilling {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Backing up…")
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                    Text("Back up local recordings now")
                                }
                                Spacer()
                            }
                        }
                        .disabled(cloudSync.isBackfilling)

                        if let summary = cloudSync.lastBackfillSummary {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let url = URL(string: "https://lecsy.app/privacy") {
                        Link(destination: url) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if let url = URL(string: "https://lecsy.app/terms") {
                        Link(destination: url) {
                            HStack {
                                Text("Terms of Service")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSignInSheet) {
                SignInSheet()
            }
            .sheet(isPresented: $showReportSheet) {
                ReportSheet()
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        do {
                            try await authService.deleteAccount()
                        } catch {
                            deleteAccountErrorMessage = ErrorMessages.friendly(error)
                            showDeleteAccountErrorAlert = true
                        }
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Failed to Delete Account", isPresented: $showDeleteAccountErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountErrorMessage)
            }
            .alert("Billing", isPresented: Binding(
                get: { billingErrorMessage != nil },
                set: { if !$0 { billingErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { billingErrorMessage = nil }
            } message: {
                Text(billingErrorMessage ?? "")
            }
        }
        .navigationViewStyle(.stack)
    }

    private func openPortal() {
        guard !isOpeningPortal else { return }
        isOpeningPortal = true
        Task {
            defer { isOpeningPortal = false }
            do {
                try await BillingService.shared.openPortal()
            } catch {
                billingErrorMessage = error.localizedDescription
            }
        }
    }

    /// サインアウト処理:
    /// - 即座にローカル状態をクリア (UX: タップ → 瞬時に login 画面)
    /// - Supabase /logout は fire-and-forget (以前は -1005 で立ち往生して UI が60秒無反応だった)
    /// - Token は 1h で自然失効するため、サーバ側 revocation の待ちは許容する
    /// - wipeLocalData=true ならローカル lecture もクリア
    /// - spinner は短時間表示 (ユーザーに押下が通った合図)
    @MainActor
    private func performSignOut(wipeLocalData: Bool) async {
        guard !isSigningOut else { return }
        isSigningOut = true

        // Supabase /logout エンドポイントへの revocation は fire-and-forget。
        // ネットワーク不達でも UI は止めない。
        Task.detached {
            try? await AuthService.shared.signOut()
        }

        // ローカル状態を即クリア → UI 側は LoginView に flip する
        authService.forceLocalSignOut()

        if wipeLocalData {
            LectureStore.shared.deleteAllData()
        }

        // spinner はごく短い間だけ出す (ボタン押下のフィードバック用)。
        try? await Task.sleep(nanoseconds: 400_000_000)
        isSigningOut = false
    }

    /// Languages available for selection (base always, extended only with kit)
    private var availableLanguages: [TranscriptionLanguage] {
        if transcriptionService.isMultilingualKitInstalled {
            return TranscriptionLanguage.allCases
        }
        return TranscriptionLanguage.baseLanguages
    }
}

// MARK: - PlanSection
//
// 2026-06-01 ローンチ:
//  - Pro via org: 常に表示（B2B 所属表示）
//  - Pro via Stripe / View Plans: feature_flags.b2c_stripe_checkout=true の時だけ表示
//    (ローンチ時 B2C は WhisperKit Free のみ、DB で flag を true にすると iOS に解放される)

private struct PlanSection: View {
    @ObservedObject var planService: PlanService = PlanService.shared
    let isOpeningPortal: Bool
    let openPortal: () -> Void

    var body: some View {
        switch planService.proSource {
        case .organization:
            Section {
                orgRow
            } header: {
                Text("Plan")
            }
        case .stripe:
            if planService.b2cCheckoutEnabled {
                Section {
                    stripeRow
                } header: {
                    Text("Plan")
                }
            }
        case .none:
            if planService.b2cCheckoutEnabled {
                Section {
                    viewPlansRow
                } header: {
                    Text("Plan")
                }
            }
        }
    }

    private var orgRow: some View {
        HStack {
            Image(systemName: "building.2")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pro (via your organization)")
                    .foregroundColor(.primary)
                Text("Managed by your organization admin.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var stripeRow: some View {
        Button(action: openPortal) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro (via Stripe subscription)")
                        .foregroundColor(.primary)
                    Text(isOpeningPortal
                         ? "Opening portal…"
                         : "Tap to manage or cancel.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isOpeningPortal {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(isOpeningPortal)
    }

    private var viewPlansRow: some View {
        Button {
            BillingService.shared.openPricing()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View Plans")
                        .foregroundColor(.primary)
                    Text("Unlock bilingual captions & AI study guide.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            LoginView()
                .navigationTitle("Sign In")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { dismiss() }
                            .buttonStyle(.plain)
                    }
                }
                .onChange(of: authService.isAuthenticated) { _, newValue in
                    if newValue { dismiss() }
                }
        }
        .navigationViewStyle(.stack)
    }
}

private func formatDownloadElapsed(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

#Preview {
    SettingsView()
}
