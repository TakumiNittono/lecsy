//
//  MiscModelTests.swift
//  lecsyTests
//
//  Tests for ReportCategory, AppLanguage, and Bundle extension
//

import Testing
import Foundation
@testable import lecsy

// MARK: - ReportCategory Tests

struct ReportCategoryTests {

    @Test func allCasesCount() {
        #expect(ReportCategory.allCases.count == 5)
    }

    @Test func rawValues() {
        #expect(ReportCategory.bug.rawValue == "bug")
        #expect(ReportCategory.crash.rawValue == "crash")
        #expect(ReportCategory.feature.rawValue == "feature")
        #expect(ReportCategory.transcription.rawValue == "transcription")
        #expect(ReportCategory.other.rawValue == "other")
    }

    @Test func displayNames() {
        #expect(ReportCategory.bug.displayName == "Bug")
        #expect(ReportCategory.crash.displayName == "Crash")
        #expect(ReportCategory.feature.displayName == "Feature Request")
        #expect(ReportCategory.transcription.displayName == "Transcription Issue")
        #expect(ReportCategory.other.displayName == "Other")
    }

    @Test func icons() {
        #expect(ReportCategory.bug.icon == "ladybug")
        #expect(ReportCategory.crash.icon == "exclamationmark.triangle")
        #expect(ReportCategory.feature.icon == "lightbulb")
        #expect(ReportCategory.transcription.icon == "text.bubble")
        #expect(ReportCategory.other.icon == "ellipsis.circle")
    }

    @Test func identifiable() {
        for category in ReportCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }

    @Test func displayNamesNonEmpty() {
        for category in ReportCategory.allCases {
            #expect(!category.displayName.isEmpty)
            #expect(!category.icon.isEmpty)
        }
    }
}

// MARK: - AppLanguage Tests

struct AppLanguageTests {

    @Test func onlyEnglish() {
        #expect(AppLanguage.allCases.count == 1)
        #expect(AppLanguage.allCases.first == .english)
    }

    @Test func rawValue() {
        #expect(AppLanguage.english.rawValue == "en")
    }

    @Test func displayName() {
        #expect(AppLanguage.english.displayName == "English")
    }

    @Test func systemDefault() {
        #expect(AppLanguage.systemDefault == .english)
    }

    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(AppLanguage.english)
        let decoded = try JSONDecoder().decode(AppLanguage.self, from: data)
        #expect(decoded == .english)
    }
}
