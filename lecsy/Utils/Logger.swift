//
//  Logger.swift
//  lecsy
//
//  セキュアなログユーティリティ
//

import Foundation
import os.log

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
struct AppLogger {
    private static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.lecsy.app"

    /// デバッグログ（DEBUGビルドのみ出力）
    nonisolated static func debug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.debug("🔍 \(message)")
        #endif
    }

    /// 情報ログ
    nonisolated static func info(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.info("ℹ️ \(message)")
        #endif
    }

    /// 警告ログ
    nonisolated static func warning(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.warning("⚠️ \(message)")
    }

    /// エラーログ
    nonisolated static func error(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ \(message)")
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
