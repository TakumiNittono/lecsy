//
//  lecsyApp.swift
//  lecsy
//
//  Created by Takuminittono on 2026/01/26.
//

import SwiftUI
import Sentry

import StoreKit
import AuthenticationServices

@main
struct lecsyApp: App {
    init() {
        // Sentry DSN は Info.plist の SENTRY_DSN (xcconfig 経由で注入) から読む。
        // ソース直書きは git 履歴に残ると git clone しただけの外部が error capture
        // を打ち込めてしまうので避ける。DSN が未設定なら SDK を起動しないだけ。
        if let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
           !dsn.isEmpty,
           dsn != "$(SENTRY_DSN)" {
            SentrySDK.start { options in
                options.dsn = dsn

                // FERPA 配慮: 学生の IP / user-agent など PII 送出を明示的に切る。
                // ユーザーID紐付けは AuthService から SentrySDK.setUser で個別に渡す方針。
                // 参考: https://docs.sentry.io/platforms/apple/data-management/data-collected/
                options.sendDefaultPii = false

                options.tracesSampleRate = 1.0

                options.configureProfiling = {
                    $0.sessionSampleRate = 1.0
                    $0.lifecycle = .trace
                }

                options.experimental.enableLogs = true
            }
        }
    }
    @StateObject private var authService = AuthService.shared
    @AppStorage("lecsy.hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.requestReview) private var requestReview
    private let streakService = StudyStreakService.shared
    // Touch TranscriptionService immediately so model preloading starts at app launch
    private let transcriptionService = TranscriptionService.shared
    // Phase 1.5 #2: instantiate PostLoginCoordinator at launch so its
    // NotificationCenter observers are registered before any sign-in event.
    @MainActor private let postLoginCoordinator = PostLoginCoordinator.shared
    // TranscriptionCoordinator を launch 時に初期化して AuthService / PlanService を
    // 購読開始させる。これで「ログイン完了 → Pro 判定 → Deepgram 事前接続」が
    // RecordView を開く前に走り、録音開始時のラグを体感ゼロにできる。
    @MainActor private let transcriptionCoordinator = TranscriptionCoordinator.shared

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
        // Custom scheme: lecsy://... (QR codes, iOS app-to-app links)
        // Universal Link: https://www.lecsy.app/... (falls through here via
        // onContinueUserActivity when AASA is configured).
        let isCustomScheme = (url.scheme == "lecsy")
        let isUniversalLink = (url.host == "lecsy.app" || url.host == "www.lecsy.app")

        guard isCustomScheme || isUniversalLink else { return }

        // OAuth callback from Google / Azure / Apple sign-in flows.
        if isCustomScheme && (url.host == "auth" || url.path.contains("callback")) {
            Task { @MainActor in
                await AuthService.shared.handleOAuthCallbackURL(url)
            }
            return
        }

        // Invite code entry: classroom pilot QR / tap link.
        //   lecsy://invite?code=FDDAD9
        //   https://www.lecsy.app/join/fmcc-pilot?code=FDDAD9
        // Kim prints a QR with either form; scanning opens the app straight
        // into "redeeming code..." without the student having to find and
        // tap the invite-code field.
        let pathLooksLikeInvite = url.host == "invite" ||
            url.path.hasPrefix("/invite") ||
            url.path.hasPrefix("/join")
        if pathLooksLikeInvite {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value
            guard let code, !code.isEmpty else {
                AppLogger.warning("lecsy invite URL without code: \(url)", category: .auth)
                return
            }
            // Already signed in? Skip redemption — trying again would error
            // with code_already_used (or worse, blow away the existing
            // session by creating a new anon user).
            if AuthService.shared.isAuthenticated {
                AppLogger.info("Invite deep-link received while already signed in — ignoring", category: .auth)
                return
            }
            Task { @MainActor in
                do {
                    try await AuthService.shared.signInWithInviteCode(code)
                    AppLogger.info("Invite deep-link redeem succeeded", category: .auth)
                } catch {
                    AppLogger.error("Invite deep-link redeem failed: \(error.localizedDescription)", category: .auth)
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