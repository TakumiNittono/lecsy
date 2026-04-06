//
//  TranscriptionResultTests.swift
//  lecsyTests
//
//  Tests for TranscriptionResult and TranscriptionSegment
//

import Testing
import Foundation
@testable import lecsy

struct TranscriptionSegmentTests {

    @Test func cleanTextRemovesWhisperTokens() {
        let segment = TranscriptionResult.TranscriptionSegment(
            startTime: 0, endTime: 5,
            text: "<|startoftranscript|><|en|> Hello world <|0.00|>"
        )
        #expect(segment.cleanText == "Hello world")
    }

    @Test func cleanTextPreservesNormalText() {
        let segment = TranscriptionResult.TranscriptionSegment(
            startTime: 0, endTime: 5, text: "Normal text without tokens"
        )
        #expect(segment.cleanText == "Normal text without tokens")
    }

    @Test func cleanTextHandlesEmptyString() {
        let segment = TranscriptionResult.TranscriptionSegment(
            startTime: 0, endTime: 1, text: ""
        )
        #expect(segment.cleanText == "")
    }

    @Test func cleanTextHandlesOnlyTokens() {
        let segment = TranscriptionResult.TranscriptionSegment(
            startTime: 0, endTime: 1, text: "<|en|><|0.00|><|endoftext|>"
        )
        #expect(segment.cleanText == "")
    }

    @Test func stripWhisperTokensStatic() {
        let input = "<|startoftranscript|><|en|><|notimestamps|> This is a test <|endoftext|>"
        let result = TranscriptionResult.TranscriptionSegment.stripWhisperTokens(input)
        #expect(result == "This is a test")
    }

    @Test func stripWhisperTokensWithTimestamps() {
        let input = "<|0.00|> Hello <|2.50|> world <|5.00|>"
        let result = TranscriptionResult.TranscriptionSegment.stripWhisperTokens(input)
        #expect(result == "Hello  world")
    }

    @Test func stripWhisperTokensPreservesAngleBrackets() {
        // Regular angle brackets (not Whisper tokens) should be preserved
        let input = "Use <html> tags"
        let result = TranscriptionResult.TranscriptionSegment.stripWhisperTokens(input)
        #expect(result == "Use <html> tags")
    }

    @Test func segmentId() {
        let segment = TranscriptionResult.TranscriptionSegment(
            startTime: 1.5, endTime: 3.0, text: "test"
        )
        #expect(segment.id == "1.5-3.0")
    }

    @Test func codableRoundTrip() throws {
        let original = TranscriptionResult.TranscriptionSegment(
            startTime: 10.5, endTime: 15.0, text: "Hello <|en|> world"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            TranscriptionResult.TranscriptionSegment.self, from: data
        )

        #expect(decoded.startTime == original.startTime)
        #expect(decoded.endTime == original.endTime)
        #expect(decoded.text == original.text)
        #expect(decoded == original)
    }

    @Test func equatable() {
        let a = TranscriptionResult.TranscriptionSegment(startTime: 0, endTime: 5, text: "Hello")
        let b = TranscriptionResult.TranscriptionSegment(startTime: 0, endTime: 5, text: "Hello")
        let c = TranscriptionResult.TranscriptionSegment(startTime: 0, endTime: 5, text: "World")
        #expect(a == b)
        #expect(a != c)
    }
}

struct TranscriptionResultTests {

    @Test func cleanTextProperty() {
        let result = TranscriptionResult(
            text: "<|en|> Hello <|0.00|> world",
            segments: [],
            language: "en",
            processingTime: 5.0
        )
        #expect(result.cleanText == "Hello  world")
    }

    @Test func codableRoundTrip() throws {
        let segments = [
            TranscriptionResult.TranscriptionSegment(startTime: 0, endTime: 5, text: "Hello"),
            TranscriptionResult.TranscriptionSegment(startTime: 5, endTime: 10, text: "World"),
        ]
        let original = TranscriptionResult(
            text: "Hello World",
            segments: segments,
            language: "en",
            processingTime: 3.5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptionResult.self, from: data)

        #expect(decoded.text == original.text)
        #expect(decoded.segments.count == 2)
        #expect(decoded.language == "en")
        #expect(decoded.processingTime == 3.5)
        #expect(decoded == original)
    }

    @Test func nilLanguage() throws {
        let original = TranscriptionResult(
            text: "Test", segments: [], language: nil, processingTime: 1.0
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptionResult.self, from: data)
        #expect(decoded.language == nil)
    }
}
