//
//  OnboardingView.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("lecsy.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("lecsy.hasAcceptedAIConsent") private var hasAcceptedAIConsent = false
    @StateObject private var transcriptionService = TranscriptionService.shared
    @State private var currentPage = 0
    @State private var isDownloading = false
    @State private var downloadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                // Privacy consent page
                privacyConsentPage
                    .tag(0)

                // AI Setup page (download)
                aiSetupPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Bottom buttons
            VStack(spacing: 12) {
                if currentPage == 1 {
                    // AI Setup page buttons
                    if transcriptionService.isModelLoaded {
                        Button(action: completeOnboarding) {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else if isDownloading {
                        Button(action: {}) {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                                Text("Downloading...")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.5))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(true)
                    } else {
                        Button(action: startModelDownload) {
                            Text("Download AI Model")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if downloadFailed {
                        Button(action: startModelDownload) {
                            Text("Retry Download")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    // Privacy consent page
                    Button(action: {
                        hasAcceptedAIConsent = true
                        currentPage = 1
                    }) {
                        Text("Agree & Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Link("Privacy Policy", destination: URL(string: "https://lecsy.app/privacy")!)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Privacy Consent Page

    private var privacyConsentPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .frame(height: 100)

            Text("Your Privacy Matters")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                privacyPoint(icon: "cpu", text: "All AI transcription runs on-device using Apple CoreML. No third-party AI service is used.")
                privacyPoint(icon: "iphone", text: "Your audio recordings never leave your device and are never sent to any external server.")
                privacyPoint(icon: "wifi", text: "Internet is only used once to download the AI model (~150 MB). No user data is transmitted.")
                privacyPoint(icon: "icloud", text: "If you sign in, only transcription text syncs to our server for cross-device access.")
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - AI Setup Page

    private var aiSetupPage: some View {
        VStack(spacing: 24) {
            Spacer()

            if transcriptionService.isModelLoaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .frame(height: 100)

                Text("AI is ready!")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Your on-device AI model is set up. You're all set to start recording and transcribing lectures.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if isDownloading {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, options: .repeating)
                        .frame(height: 100)

                    Text("Setting up AI")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(transcriptionService.downloadStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: transcriptionService.progress)
                        .tint(.blue)
                        .padding(.horizontal, 48)

                    Text("\(Int(transcriptionService.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else if downloadFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .frame(height: 100)

                Text("Download failed")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Please check your internet connection and try again. You can also download the model later from Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .frame(height: 100)

                Text("Set up AI transcription")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Download the AI model (~150 MB, one-time) to enable offline transcription. No internet needed after this.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Feature badges
                HStack(spacing: 16) {
                    featureBadge(icon: "lock.shield.fill", text: "Private")
                    featureBadge(icon: "wifi.slash", text: "Offline")
                    featureBadge(icon: "bolt.fill", text: "Fast")
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }

    private func featureBadge(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 72)
    }

    // MARK: - Actions

    private func startModelDownload() {
        isDownloading = true
        downloadFailed = false
        Task {
            do {
                try await transcriptionService.loadModel()
                isDownloading = false
            } catch {
                isDownloading = false
                downloadFailed = true
            }
        }
    }

    private func completeOnboarding() {
        hasSeenOnboarding = true
    }
}

#Preview {
    OnboardingView()
}
