//
//  AppLoggerTests.swift
//  lecsyTests
//
//  Tests for AppLogger utility (maskSensitive)
//

import Testing
import Foundation
@testable import lecsy

struct AppLoggerTests {

    @Test func maskSensitiveWithLongString() {
        let result = AppLogger.maskSensitive("abcdefghij", visibleChars: 4)
        #expect(result == "abcd***[length:10]")
    }

    @Test func maskSensitiveWithDefaultVisibleChars() {
        let result = AppLogger.maskSensitive("secrettoken123")
        // Default visibleChars is 4
        #expect(result == "secr***[length:14]")
    }

    @Test func maskSensitiveWithShortString() {
        // When string length <= visibleChars, return all asterisks
        let result = AppLogger.maskSensitive("abc", visibleChars: 4)
        #expect(result == "***")
    }

    @Test func maskSensitiveExactLength() {
        // When string length == visibleChars, return all asterisks
        let result = AppLogger.maskSensitive("abcd", visibleChars: 4)
        #expect(result == "****")
    }

    @Test func maskSensitiveEmptyString() {
        let result = AppLogger.maskSensitive("")
        #expect(result == "")
    }

    @Test func maskSensitiveSingleChar() {
        let result = AppLogger.maskSensitive("x", visibleChars: 4)
        #expect(result == "*")
    }

    @Test func maskSensitiveWithCustomVisibleChars() {
        let result = AppLogger.maskSensitive("abcdefghij", visibleChars: 8)
        #expect(result == "abcdefgh***[length:10]")
    }

    @Test func maskSensitiveWithZeroVisibleChars() {
        // visibleChars: 0 — since count(1) > 0, show prefix(0) + mask
        let result = AppLogger.maskSensitive("a", visibleChars: 0)
        #expect(result == "***[length:1]")
    }
}

// MARK: - LogCategory Tests

struct LogCategoryTests {

    @Test func allRawValues() {
        #expect(LogCategory.auth.rawValue == "Auth")
        #expect(LogCategory.sync.rawValue == "Sync")
        #expect(LogCategory.recording.rawValue == "Recording")
        #expect(LogCategory.transcription.rawValue == "Transcription")
        #expect(LogCategory.audio.rawValue == "Audio")
        #expect(LogCategory.storage.rawValue == "Storage")
        #expect(LogCategory.general.rawValue == "General")
    }
}
