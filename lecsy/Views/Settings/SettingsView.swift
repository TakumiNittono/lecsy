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

                // Transcription Method — Pro (org member) のみ表示。
                // Free プランは常にオンデバイス (WhisperKit) 固定なので何も出さない。
                // 2026-04-26 (お父様フィードバック対応): "On-Device Only" toggle と
                // サブテキスト "Using cloud transcription" が並んで矛盾に読める事故を解消、
                // 2 行の選択肢 (Cloud / On-device) UI に変更。詳細は TranscriptionMethodSection。
                if planService.isProEntitled {
                    TranscriptionMethodSection()
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

                PrivacySection(
                    cloudSyncEnabled: $cloudSyncEnabled,
                    isAuthenticated: authService.isAuthenticated
                )

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
        case .apple:
            // Week 2 (5/4 〜) で PaywallView / Manage Subscription / Restore を実装する。
            // 現状は IAP 導線が iOS 側に存在しないので、ここに到達するルートも無い。
            // 将来、AppStore.showManageSubscriptions(in:) を起こす Subscription セクションを差し込む。
            EmptyView()
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
                    Text("Unlock cloud transcription & AI study guide.")
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

/// Transcription Method セクション (Pro 専用)。
///
/// 旧 UI: "On-Device Only" toggle + サブテキスト "Using cloud transcription"。
/// → 並んで読まれた時に意味が逆転して見える事故 (お父様フィードバック 2026-04-26)。
/// 新 UI: 2 行の checkmark 選択肢 (Cloud / On-device)、各行に挙動の note を併記。
private struct TranscriptionMethodSection: View {
    @AppStorage(PlanService.forceLocalKey) private var forceLocalTranscription: Bool = false
    @ObservedObject private var planService: PlanService = PlanService.shared

    var body: some View {
        Section {
            row(
                isOnDevice: false,
                title: "Cloud",
                subtitle: "Faster · more accurate · live captions",
                note: "Requires internet"
            )
            row(
                isOnDevice: true,
                title: "On-device",
                subtitle: "Audio never leaves this iPhone",
                note: "Live captions disabled"
            )
        } header: {
            Text("Transcription Method")
        }
    }

    @ViewBuilder
    private func row(isOnDevice: Bool, title: String, subtitle: String, note: String) -> some View {
        let selected = (forceLocalTranscription == isOnDevice)
        Button {
            guard forceLocalTranscription != isOnDevice else { return }
            forceLocalTranscription = isOnDevice
            DispatchQueue.main.async {
                planService.objectWillChange.send()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selected ? .accentColor : .secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Privacy セクション。SettingsView.body inline だと SwiftUI の type-checker が
/// time out するため別 struct に切り出し。Cloud Sync トグル + audio retention +
/// バックアップボタン + 法務リンク で構成、footer に「音声は端末から出ない / AI 学習に
/// 使わない」の 1 行コミット (FERPA / Apple App Privacy 上、最低限明示しておく)。
private struct PrivacySection: View {
    @Binding var cloudSyncEnabled: Bool
    let isAuthenticated: Bool
    @ObservedObject private var cloudSync = CloudSyncService.shared

    var body: some View {
        Section {
            Toggle("Cloud Sync", isOn: $cloudSyncEnabled)
                .onChange(of: cloudSyncEnabled) { _, newValue in
                    CloudSyncService.shared.setEnabled(newValue)
                }

            Picker("Delete audio after", selection: Binding(
                get: { RecordingRetention.current },
                set: { RecordingRetention.set($0) }
            )) {
                ForEach(RecordingRetention.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            if isAuthenticated && cloudSyncEnabled {
                backfillButton
                if let summary = cloudSync.lastBackfillSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            policyLink(label: "Privacy Policy", urlString: "https://lecsy.app/privacy")
            policyLink(label: "Terms of Service", urlString: "https://lecsy.app/terms")
        } header: {
            Text("Privacy")
        } footer: {
            // PrivacyInfo.xcprivacy と Info.plist (NSMicrophoneUsageDescription) の事実に
            // 揃える: 音声ファイル (.m4a) はどのプランでも端末のみ。Free=WhisperKit on-device、
            // Pro=Deepgram に短時間 stream して 30 日以内自動削除 (Lecsy 側で永続保存はしない)。
            // "Audio stays on your device" は Pro で嘘になるので、Lecsy server に保存しない、
            // という正確な表現に統一する。
            Text("Lecsy doesn't store your audio on its servers. On the Free plan, transcription runs on this iPhone. On paid plans, audio is sent to Deepgram for live transcription and auto-deleted within 30 days. Only transcript text is synced to your account. Your data is never used to train AI.")
        }
    }

    @ViewBuilder
    private var backfillButton: some View {
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
    }

    @ViewBuilder
    private func policyLink(label: String, urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack {
                    Text(label).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption).foregroundColor(.secondary)
                }
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
