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
    private let streakService = StudyStreakService.shared
    // Touch TranscriptionService immediately so model preloading starts at app launch
    private let transcriptionService = TranscriptionService.shared
    // Phase 1.5 #2: instantiate PostLoginCoordinator at launch so its
    // NotificationCenter observers are registered before any sign-in event.
    @MainActor private let postLoginCoordinator = PostLoginCoordinator.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else {
                    ContentView()
                        .onReceive(NotificationCenter.default.publisher(for: .lectureRecordingCompleted)) { _ in
                            checkAndRequestReview()
                        }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
            .task {
                recoverStuckTranscriptions()
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


    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "lecsy" {
            if url.host == "auth" || url.path.contains("callback") {
                Task { @MainActor in
                    await AuthService.shared.handleOAuthCallbackURL(url)
                }
            }
        }
    }

    /// Recover lectures stuck in .processing from a previous crash
    @MainActor
    private func recoverStuckTranscriptions() {
        let store = LectureStore.shared
        for lecture in store.lectures where lecture.transcriptStatus == .processing {
            var updated = lecture
            // If partial transcript exists, mark as failed so user can retry
            // (partial text is preserved for viewing)
            updated.transcriptStatus = .failed
            store.updateLecture(updated)
            AppLogger.warning("Recovered stuck transcription for lecture: \(lecture.displayTitle)", category: .transcription)
        }
    }

    private static let reviewThreshold = 5
    private static let reviewDelaySeconds: Double = 2.0
    private static let completedRecordingsKey = "lecsy.completedRecordingsCount"
    private static let reviewRequestedKey = "lecsy.hasRequestedReview"

    private func checkAndRequestReview() {
        let count = UserDefaults.standard.integer(forKey: Self.completedRecordingsKey) + 1
        UserDefaults.standard.set(count, forKey: Self.completedRecordingsKey)

        if count >= Self.reviewThreshold && !UserDefaults.standard.bool(forKey: Self.reviewRequestedKey) {
            UserDefaults.standard.set(true, forKey: Self.reviewRequestedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.reviewDelaySeconds) {
                self.requestReview()
            }
        }
    }
}

extension Notification.Name {
    static let lectureRecordingCompleted = Notification.Name("lecsy.lectureRecordingCompleted")
}