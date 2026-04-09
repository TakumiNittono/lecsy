//
//  SettingsView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared

    @State private var showSignInSheet = false
    @State private var showSignOutDialog = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountErrorAlert = false
    @State private var deleteAccountErrorMessage = ""
    @State private var isDeletingAccount = false
    @State private var showReportSheet = false
    @State private var cloudSyncEnabled = CloudSyncService.shared.isEnabled
    @ObservedObject private var cloudSync = CloudSyncService.shared

    var body: some View {
        NavigationView {
            List {
                // Transcription Language
                Section {
                    // Dropdown picker (Menu style) — single row instead of long list
                    Picker("Language", selection: Binding(
                        get: { transcriptionService.transcriptionLanguage },
                        set: { transcriptionService.setLanguage($0) }
                    )) {
                        ForEach(availableLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)

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
                                        Text("日本語, 한국어, 中文, Español and more")
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

                        Button("Sign Out", role: .destructive) {
                            showSignOutDialog = true
                        }
                        .confirmationDialog(
                            "Sign Out?",
                            isPresented: $showSignOutDialog,
                            titleVisibility: .visible
                        ) {
                            Button("Sign Out", role: .destructive) {
                                Task {
                                    do {
                                        try await authService.signOut()
                                    } catch {
                                        deleteAccountErrorMessage = error.localizedDescription
                                        showDeleteAccountErrorAlert = true
                                    }
                                }
                            }
                            Button("Sign Out & Delete Data on This Device", role: .destructive) {
                                Task {
                                    do {
                                        try await authService.signOut()
                                        await MainActor.run {
                                            LectureStore.shared.deleteAllData()
                                        }
                                    } catch {
                                        deleteAccountErrorMessage = error.localizedDescription
                                        showDeleteAccountErrorAlert = true
                                    }
                                }
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
                            deleteAccountErrorMessage = error.localizedDescription
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
        }
        .navigationViewStyle(.stack)
    }

    /// Languages available for selection (base always, extended only with kit)
    private var availableLanguages: [TranscriptionLanguage] {
        if transcriptionService.isMultilingualKitInstalled {
            return TranscriptionLanguage.allCases
        }
        return TranscriptionLanguage.baseLanguages
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
