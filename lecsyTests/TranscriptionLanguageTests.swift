//
//  TranscriptionLanguageTests.swift
//  lecsyTests
//
//  Tests for TranscriptionLanguage enum
//

import Testing
import Foundation
@testable import lecsy

struct TranscriptionLanguageTests {

    @Test func allCasesCount() {
        #expect(TranscriptionLanguage.allCases.count == 9)
    }

    @Test func rawValues() {
        #expect(TranscriptionLanguage.english.rawValue == "en")
        #expect(TranscriptionLanguage.japanese.rawValue == "ja")
        #expect(TranscriptionLanguage.spanish.rawValue == "es")
        #expect(TranscriptionLanguage.french.rawValue == "fr")
        #expect(TranscriptionLanguage.german.rawValue == "de")
        #expect(TranscriptionLanguage.portuguese.rawValue == "pt")
        #expect(TranscriptionLanguage.italian.rawValue == "it")
        #expect(TranscriptionLanguage.russian.rawValue == "ru")
        #expect(TranscriptionLanguage.hindi.rawValue == "hi")
    }

    @Test func displayNames() {
        #expect(TranscriptionLanguage.english.displayName == "English")
        #expect(TranscriptionLanguage.japanese.displayName == "日本語")
        #expect(TranscriptionLanguage.spanish.displayName == "Español")
        #expect(TranscriptionLanguage.hindi.displayName == "हिन्दी")
    }

    @Test func flags() {
        #expect(TranscriptionLanguage.english.flag == "🇺🇸")
        #expect(TranscriptionLanguage.japanese.flag == "🇯🇵")
        #expect(TranscriptionLanguage.spanish.flag == "🇪🇸")
    }

    @Test func deepgramCodeMatchesRawValue() {
        for language in TranscriptionLanguage.allCases {
            #expect(language.deepgramCode == language.rawValue)
        }
    }

    @Test func shortNames() {
        #expect(TranscriptionLanguage.english.shortName == "ENG")
        #expect(TranscriptionLanguage.japanese.shortName == "日本語")
        #expect(TranscriptionLanguage.spanish.shortName == "ESP")
    }

    @Test func whisperLanguageMatchesRawValue() {
        for language in TranscriptionLanguage.allCases {
            #expect(language.whisperLanguage == language.rawValue)
        }
    }

    @Test func requiresMultilingualKit() {
        #expect(TranscriptionLanguage.english.requiresMultilingualKit == false)

        let extendedLanguages: [TranscriptionLanguage] = [
            .japanese, .spanish, .french, .german,
            .portuguese, .italian, .russian, .hindi
        ]
        for lang in extendedLanguages {
            #expect(lang.requiresMultilingualKit == true,
                    "\(lang.displayName) should require multilingual kit")
        }
    }

    @Test func baseLanguages() {
        let base = TranscriptionLanguage.baseLanguages
        #expect(base.count == 1)
        #expect(base.contains(.english))
    }

    @Test func extendedLanguages() {
        let extended = TranscriptionLanguage.extendedLanguages
        #expect(extended.count == 8)
        #expect(!extended.contains(.english))
        #expect(extended.contains(.japanese))
        #expect(extended.contains(.hindi))
    }

    @Test func baseAndExtendedCoverAllCases() {
        let all = Set(TranscriptionLanguage.baseLanguages + TranscriptionLanguage.extendedLanguages)
        let expected = Set(TranscriptionLanguage.allCases)
        #expect(all == expected)
    }

    @Test func lecturePromptNonEmpty() {
        for language in TranscriptionLanguage.allCases {
            #expect(!language.lecturePrompt.isEmpty,
                    "\(language.displayName) should have a non-empty lecture prompt")
        }
    }

    @Test func codableRoundTrip() throws {
        for language in TranscriptionLanguage.allCases {
            let data = try JSONEncoder().encode(language)
            let decoded = try JSONDecoder().decode(TranscriptionLanguage.self, from: data)
            #expect(decoded == language)
        }
    }

    @Test func decodeFromRawValue() throws {
        let json = "\"ja\""
        let decoded = try JSONDecoder().decode(
            TranscriptionLanguage.self, from: Data(json.utf8)
        )
        #expect(decoded == .japanese)
    }
}
