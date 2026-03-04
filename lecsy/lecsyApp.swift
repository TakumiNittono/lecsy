//
//  lecsyApp.swift
//  lecsy
//
//  Created by Takuminittono on 2026/01/26.
//

import SwiftUI
import StoreKit
import AuthenticationServices

@main
struct lecsyApp: App {
    @StateObject private var authService = AuthService.shared
    @AppStorage("lecsy.hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.requestReview) private var requestReview
    private let syncService = SyncService.shared
    private let streakService = StudyStreakService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else if !authService.isInitialized {
                    // Splash screen while restoring session
                    splashScreen
                } else if authService.isAuthenticated || authService.hasSkippedLogin {
                    ContentView()
                        .task {
                            await syncTitlesOnLaunch()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .lectureRecordingCompleted)) { _ in
                            checkAndRequestReview()
                        }
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.isInitialized)
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authService.hasSkippedLogin)
            .task {
                // Start AI model download immediately on app launch (if onboarding is done)
                if hasSeenOnboarding {
                    await preloadModelIfNeeded()
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    handleIncomingURL(url)
                }
            }
        }
    }

    private var splashScreen: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("Lecsy")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "lecsy" {
            if url.host == "auth" || url.path.contains("callback") {
                Task { @MainActor in
                    await AuthService.shared.handleOAuthCallbackURL(url)
                }
            }
        }
    }

    @MainActor
    private func preloadModelIfNeeded() async {
        let transcriptionService = TranscriptionService.shared
        guard !transcriptionService.isModelLoaded else { return }
        try? await transcriptionService.loadModel()
    }

    @MainActor
    private func syncTitlesOnLaunch() async {
        guard await authService.isSessionValid else { return }

        do {
            try await syncService.syncTitlesFromWeb()
        } catch {
            // Ignore errors (don't block app launch)
        }
    }

    private func checkAndRequestReview() {
        let key = "lecsy.completedRecordingsCount"
        let reviewRequestedKey = "lecsy.hasRequestedReview"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)

        if count >= 5 && !UserDefaults.standard.bool(forKey: reviewRequestedKey) {
            UserDefaults.standard.set(true, forKey: reviewRequestedKey)
            // Delay slightly so the UI settles first
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                requestReview()
            }
        }
    }
}

extension Notification.Name {
    static let lectureRecordingCompleted = Notification.Name("lecsy.lectureRecordingCompleted")
}
