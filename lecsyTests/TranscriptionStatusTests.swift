//
//  TranscriptionStatusTests.swift
//  lecsyTests
//
//  Tests for TranscriptionStatus enum
//

import Testing
import Foundation
@testable import lecsy

struct TranscriptionStatusTests {

    @Test func rawValues() {
        #expect(TranscriptionStatus.notStarted.rawValue == "not_started")
        #expect(TranscriptionStatus.downloading.rawValue == "downloading")
        #expect(TranscriptionStatus.processing.rawValue == "processing")
        #expect(TranscriptionStatus.completed.rawValue == "completed")
        #expect(TranscriptionStatus.failed.rawValue == "failed")
    }

    @Test func displayNames() {
        #expect(TranscriptionStatus.notStarted.displayName == "Not Started")
        #expect(TranscriptionStatus.downloading.displayName == "Downloading Model")
        #expect(TranscriptionStatus.processing.displayName == "Transcribing")
        #expect(TranscriptionStatus.completed.displayName == "Completed")
        #expect(TranscriptionStatus.failed.displayName == "Failed")
    }

    @Test func codableRoundTrip() throws {
        let allCases: [TranscriptionStatus] = [
            .notStarted, .downloading, .processing, .completed, .failed
        ]
        for status in allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TranscriptionStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test func decodeFromRawValue() throws {
        let json = "\"not_started\""
        let decoded = try JSONDecoder().decode(
            TranscriptionStatus.self, from: Data(json.utf8)
        )
        #expect(decoded == .notStarted)
    }

    @Test func decodeInvalidRawValueThrows() {
        let json = "\"invalid\""
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                TranscriptionStatus.self, from: Data(json.utf8)
            )
        }
    }
}
