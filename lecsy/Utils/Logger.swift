//
//  Logger.swift
//  lecsy
//
//  セキュアなログユーティリティ + Sentry ミラー (error / warning のみ)
//

import Foundation
import os.log

#if canImport(Sentry)
import Sentry
#endif

/// アプリケーションログカテゴリ
enum LogCategory: String {
    case auth = "Auth"
    case sync = "Sync"
    case recording = "Recording"
    case transcription = "Transcription"
    case audio = "Audio"
    case storage = "Storage"
    case general = "General"
}

/// セキュアなログユーティリティ。
/// Swift 6 strict concurrency で `Bundle.main` が MainActor-isolated と推論される場合に、
/// 静的メソッド全体が MainActor 推論されて "cannot be called from outside the actor" が
/// 各呼び出し点（RecordingService / LectureStore など非 MainActor コンテキスト）で
/// 起こる。全てを明示的に `nonisolated` にして推論を断ち切る。
///
/// Sentry:
///   - `warning` / `error` は SDK が読み込まれていれば自動的に Sentry にミラー送出
///   - `debug` / `info` はローカル os.log のみ (Sentry ノイズ回避)
///   - Sentry 未リンク環境 (DEBUG ビルドで SPM 未解決等) は `#if canImport(Sentry)` で no-op
struct AppLogger {
    private static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.lecsy.app"

    /// Sentry が `SentrySDK.start` で初期化済かを示す flag。SENTRY_DSN が
    /// Info.plist に未設定の build (Debug / 個人開発の simulator 動作確認等)
    /// では Sentry は起動しない。その状態で `SentrySDK.addBreadcrumb` を
    /// 呼ぶと `[Sentry] [fatal] The SDK is disabled` という fatal 級の
    /// log spam が出てログが読めなくなる。`lecsyApp.bootSentry` の最後で
    /// `markSentryStarted()` を呼んで true に上げ、`breadcrumb` / `capture`
    /// 系はこの flag を見て早期 return する。
    nonisolated(unsafe) private static var _sentryStarted: Bool = false
    nonisolated static var isSentryStarted: Bool { _sentryStarted }
    nonisolated static func markSentryStarted() { _sentryStarted = true }

    /// デバッグログ（DEBUGビルドのみ出力、Sentry 送出なし）
    nonisolated static func debug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.debug("🔍 \(message)")
        #endif
    }

    /// 情報ログ (Sentry 送出なし)
    nonisolated static func info(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.info("ℹ️ \(message)")
        #endif
    }

    /// 警告ログ (Sentry に warning 送出)
    nonisolated static func warning(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.warning("⚠️ \(message)")
        #if canImport(Sentry)
        SentrySDK.capture(message: "[\(category.rawValue)] \(message)") { scope in
            scope.setLevel(.warning)
            scope.setTag(value: category.rawValue, key: "category")
        }
        #endif
    }

    /// エラーログ (Sentry に error 送出)
    nonisolated static func error(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ \(message)")
        #if canImport(Sentry)
        SentrySDK.capture(message: "[\(category.rawValue)] \(message)") { scope in
            scope.setLevel(.error)
            scope.setTag(value: category.rawValue, key: "category")
        }
        #endif
    }

    /// Sentry の global scope に tag を 1 つ set する。runtime に user の状態
    /// (plan / current flow / current subsystem) が変わったときに、それ以降に
    /// 起きる error event 全てにこの tag が attach される。Sentry UI の
    /// 「特定 plan / flow で起きる error だけ filter」を可能にする。
    /// Sentry 未リンク環境では no-op。
    nonisolated static func setSentryTag(_ key: String, value: String) {
        #if canImport(Sentry)
        SentrySDK.configureScope { scope in
            scope.setTag(value: value, key: key)
        }
        #endif
    }

    /// Sentry に breadcrumb を残す (event そのものは生成しない)。次に発生する
    /// error / crash の event に attach されて context として届く。
    /// chunked transcription / 録音まわりの「どこまで進んだか」を Peter の
    /// iPad クラッシュ調査 (2026-05-05 incident) で追跡するために導入。
    /// 本体 log は `AppLogger.info` と同じ os.log + DEBUG ガード。Sentry 側は
    /// breadcrumb なので noise にならない。
    nonisolated static func breadcrumb(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.info("🍞 \(message)")
        #endif
        #if canImport(Sentry)
        // SDK 未起動 (SENTRY_DSN 未設定 build) では fatal 級の log spam を吐く
        // ので gate する。
        guard isSentryStarted else { return }
        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = category.rawValue
        crumb.message = message
        crumb.type = "default"
        SentrySDK.addBreadcrumb(crumb)
        #endif
    }

    /// Swift `Error` オブジェクトを直接送信 (スタック/ドメインが保持される)。
    /// 例外を catch した文脈で呼ぶと Sentry UI での可読性が `error(message:)` より高い。
    nonisolated static func capture(_ error: Error, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ \(error.localizedDescription)")
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: category.rawValue, key: "category")
        }
        #endif
    }

    /// 固定 fingerprint 付きで error を Sentry に送る。Sentry の Issue grouping は
    /// default だと message + stack trace で hash を取るため、同じ root cause でも
    /// chunk index 違い / retry 回数違い / file path 違い等で event が分散して
    /// 全部別 Issue になる。fingerprint を明示的に固定すると、それらが 1 つの
    /// Issue にまとめられて再発回数 / 影響 user 数が一目で見える。
    /// `tags` は per-event のメタ情報。`AppLogger.setSentryTag` の global tag に
    /// 加えて、特定 event 固有の context (例: `chunk_index=3`) を載せる。
    nonisolated static func captureFingerprinted(
        _ error: Error,
        fingerprint: [String],
        tags: [String: String] = [:],
        category: LogCategory = .general
    ) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ [\(fingerprint.joined(separator: "/"))] \(error.localizedDescription)")
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            scope.setFingerprint(fingerprint)
            scope.setTag(value: category.rawValue, key: "category")
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
        }
        #endif
    }

    /// `captureFingerprinted` の message variant。Swift `Error` が手元に無い時に。
    nonisolated static func captureMessageFingerprinted(
        _ message: String,
        fingerprint: [String],
        tags: [String: String] = [:],
        level: String = "error",
        category: LogCategory = .general
    ) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ [\(fingerprint.joined(separator: "/"))] \(message)")
        #if canImport(Sentry)
        SentrySDK.capture(message: "[\(category.rawValue)] \(message)") { scope in
            scope.setFingerprint(fingerprint)
            scope.setLevel(level == "warning" ? .warning : .error)
            scope.setTag(value: category.rawValue, key: "category")
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
        }
        #endif
    }

    /// 機密情報をマスクする
    nonisolated static func maskSensitive(_ value: String, visibleChars: Int = 4) -> String {
        guard value.count > visibleChars else {
            return String(repeating: "*", count: value.count)
        }
        let visible = value.prefix(visibleChars)
        return "\(visible)***[length:\(value.count)]"
    }

    /// トークン情報のログ（DEBUGビルドのみ、マスク付き）
    nonisolated static func logToken(_ label: String, token: String?, category: LogCategory = .auth) {
        #if DEBUG
        if let token = token {
            // Show only 4 leading chars — enough to correlate in logs,
            // never enough to reconstruct a usable token even if a DEBUG
            // build's console output is shared with a QA tester.
            debug("\(label): \(maskSensitive(token, visibleChars: 4))", category: category)
        } else {
            debug("\(label): nil", category: category)
        }
        #endif
    }
}
