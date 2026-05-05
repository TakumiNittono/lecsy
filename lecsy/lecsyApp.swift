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
    // Sentry を **他の stored property より先に** 起動するためのブート。
    // Swift の stored property は宣言順に init されるため、これを最上段に置くと
    // AuthService.shared / TranscriptionService.shared など「.shared 経由で
    // SentrySDK.setUser を呼ぶ系」が走る前に必ず SentrySDK.start が完了する。
    // 旧コードは init() 本体で start していたが、stored property の初期化は
    // init() 本体より先に走るため、launch 直後の session 復元で
    // "The SDK is disabled, so setUser doesn't work" が出ていた。
    private let _sentryBoot: Void = lecsyApp.bootSentry()

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

    /// 一度だけ走る Sentry init。Bundle / Info.plist の SENTRY_DSN を読む。
    /// ソース直書きは git 履歴に残るので回避（外部からの error capture spam を防ぐ）。
    private static func bootSentry() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty,
              dsn != "$(SENTRY_DSN)" else {
            return
        }
        // release tag: Sentry の Issue 一覧で「どの build で死んだか」を即判別
        // できるようにする。default の自動 release 名は bundle id ベースで人間に
        // 読みづらいので、`lecsy@<short>+<build>` 形式に固定。
        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
        let buildVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
        let releaseTag = "lecsy@\(shortVersion)+\(buildVersion)"

        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = releaseTag
            // FERPA 配慮: 学生の IP / user-agent など PII 送出を明示的に切る。
            // ユーザーID紐付けは AuthService から SentrySDK.setUser で個別に渡す方針。
            options.sendDefaultPii = false
            options.tracesSampleRate = 1.0
            options.configureProfiling = {
                $0.sessionSampleRate = 1.0
                $0.lifecycle = .trace
            }
            options.experimental.enableLogs = true
            // MetricKit ingestion: jetsam / OOM / hang / cpuException を OS の
            // MXMetricManager 経由で受け取って Sentry に送る。通常 crash と違い
            // jetsam は signal handler を経由しないので、これが唯一の捕捉経路。
            // Peter Ullsperger 2026-05-05 incident (silent kill 仮説) で導入。
            options.enableMetricKit = true
        }
        // device profile を Sentry scope に詰める。jetsam で死んだ user の
        // device 分布が見えないと「低スペがどれだけ死んでいるか」が判らない。
        // model identifier は uname machine ("iPad14,1" 等)、UIDevice.model だと
        // 全部 "iPad"/"iPhone" になって役に立たない。
        SentrySDK.configureScope { scope in
            var sysinfo = utsname()
            uname(&sysinfo)
            let machineMirror = Mirror(reflecting: sysinfo.machine)
            let modelIdentifier = machineMirror.children.reduce("") { partial, element in
                guard let value = element.value as? Int8, value != 0 else { return partial }
                return partial + String(UnicodeScalar(UInt8(value)))
            }
            let physRAMGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
            let osVersion = UIDevice.current.systemVersion
            let idiom: String = {
                switch UIDevice.current.userInterfaceIdiom {
                case .phone: return "iPhone"
                case .pad: return "iPad"
                case .mac: return "Mac"
                case .tv: return "tv"
                case .carPlay: return "carPlay"
                case .vision: return "vision"
                default: return "unknown"
                }
            }()
            scope.setTag(value: modelIdentifier, key: "device.model_id")
            scope.setTag(value: String(format: "%.1fGB", physRAMGB), key: "device.ram")
            scope.setTag(value: osVersion, key: "device.os_version")
            scope.setTag(value: idiom, key: "device.idiom")
            // dual-instance threshold (8GB) を満たすかも tag で出す。
            // jetsam 発生時に "dual=true で死んでいる" が一目で見える。
            scope.setTag(
                value: ProcessInfo.processInfo.physicalMemory >= 8_000_000_000 ? "true" : "false",
                key: "lecsy.whisper_dual_eligible"
            )
            // build_channel: TestFlight (sandbox) / App Store / DEBUG を識別。
            // Sentry の Issue 検索で "本番のみ出ている bug" を絞れる。
            #if DEBUG
            let channel = "debug"
            #else
            let isTestFlight = (Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt")
            let channel = isTestFlight ? "testflight" : "appstore"
            #endif
            scope.setTag(value: channel, key: "build_channel")
            scope.setTag(value: shortVersion, key: "app.version")
            scope.setTag(value: buildVersion, key: "app.build")
        }
    }

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

    /// Recover lectures stuck in .processing from a previous crash.
    /// 起動時に WhisperLiveDecoder の chunkCache が残っていれば、復元前に
    /// stitch を試行する。cache が完結していれば .completed に直して、
    /// 完結していなければ .failed にして user の retry を待つ。
    @MainActor
    private func recoverStuckTranscriptions() {
        let store = LectureStore.shared
        let transcriptionService = TranscriptionService.shared
        for lecture in store.lectures where lecture.transcriptStatus == .processing {
            // live decode cache が残っていれば復元を試行
            let completion = transcriptionService.liveCacheCompletion(
                lectureId: lecture.id,
                totalDuration: lecture.duration
            )
            if completion.isComplete {
                let stitched = transcriptionService.stitchLiveCachedChunks(completion.chunks)
                var updated = lecture
                updated.transcriptText = stitched.text
                updated.transcriptSegments = stitched.segments
                updated.transcriptStatus = .completed
                store.updateLecture(updated)
                transcriptionService.clearChunkCache(lectureId: lecture.id)
                AppLogger.info("Recovered stuck lecture \(lecture.displayTitle) via live cache (\(completion.chunks.count) chunks)", category: .transcription)
                continue
            }

            // cache 不完全 → partial を残して .failed に
            var updated = lecture
            if !completion.chunks.isEmpty {
                let stitched = transcriptionService.stitchLiveCachedChunks(completion.chunks)
                updated.transcriptText = stitched.text
                updated.transcriptSegments = stitched.segments
                AppLogger.warning("Recovered stuck lecture \(lecture.displayTitle) with partial cache (\(completion.chunks.count) chunks, coverage \(Int(completion.coverage))s) — marking failed", category: .transcription)
            } else {
                AppLogger.warning("Recovered stuck transcription for lecture: \(lecture.displayTitle) (no cache)", category: .transcription)
            }
            updated.transcriptStatus = .failed
            store.updateLecture(updated)
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
