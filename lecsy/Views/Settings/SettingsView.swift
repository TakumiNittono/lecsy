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
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountErrorAlert = false
    @State private var deleteAccountErrorMessage = ""
    @State private var isDeletingAccount = false
    @State private var isDownloadingModel = false
    @State private var showClearCacheAlert = false

    var body: some View {
        NavigationView {
            List {
                // AI Model section
                Section("AI Model") {
                    HStack {
                        if transcriptionService.isModelLoaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready")
                        } else if transcriptionService.state == .downloading || isDownloadingModel {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Downloading...")
                                .foregroundColor(.secondary)
                        } else if transcriptionService.isModelAvailable() {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.orange)
                            Text("Cached (not loaded)")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.secondary)
                            Text("Not Downloaded")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    if transcriptionService.state == .downloading || isDownloadingModel {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: transcriptionService.progress)
                                .tint(.blue)
                            Text(transcriptionService.downloadStatusText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !transcriptionService.isModelLoaded && !isDownloadingModel {
                        Button {
                            Task {
                                isDownloadingModel = true
                                try? await transcriptionService.loadModel()
                                isDownloadingModel = false
                            }
                        } label: {
                            Label("Download Model (~150 MB)", systemImage: "arrow.down.circle")
                        }
                    }

                    if transcriptionService.isModelAvailable() || transcriptionService.isModelLoaded {
                        Button(role: .destructive) {
                            showClearCacheAlert = true
                        } label: {
                            Label("Clear Cache", systemImage: "trash")
                        }
                    }
                }

                // Account section
                Section("Account") {
                    if authService.isAuthenticated {
                        if let user = authService.currentUser {
                            HStack {
                                Text("Signed in as:")
                                Spacer()
                                Text(user.email ?? "Unknown")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button("Sign Out", role: .destructive) {
                            Task {
                                try? await authService.signOut()
                            }
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
                        Button("Sign In") {
                            showSignInSheet = true
                        }
                    }
                }

                // Privacy section
                Section("Privacy") {
                    Link(destination: URL(string: "https://lecsy.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://lecsy.app/terms")!) {
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
            .alert("Clear Model Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    try? transcriptionService.clearModelCache()
                }
            } message: {
                Text("The AI model will need to be downloaded again before transcription.")
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Sign in to sync lectures with the web app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                try await authService.signInWithGoogle()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)

                    Button(action: {
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                try await authService.signInWithApple()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    SettingsView()
}
