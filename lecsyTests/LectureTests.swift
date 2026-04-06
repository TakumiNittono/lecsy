//
//  LectureTests.swift
//  lecsyTests
//
//  Tests for Lecture model and LectureBookmark
//

import Testing
import Foundation
@testable import lecsy

// MARK: - LectureBookmark Tests

struct LectureBookmarkTests {

    @Test func initWithDefaults() {
        let bookmark = LectureBookmark(timestamp: 42.5)
        #expect(bookmark.timestamp == 42.5)
        #expect(bookmark.label == "Bookmark")
        #expect(bookmark.id != UUID()) // has a unique ID
    }

    @Test func initWithCustomLabel() {
        let bookmark = LectureBookmark(timestamp: 10.0, label: "Important")
        #expect(bookmark.label == "Important")
        #expect(bookmark.timestamp == 10.0)
    }

    @Test func codableRoundTrip() throws {
        let original = LectureBookmark(timestamp: 99.9, label: "Test Label")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LectureBookmark.self, from: data)
        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.label == original.label)
    }

    @Test func equatable() {
        let id = UUID()
        let a = LectureBookmark(id: id, timestamp: 5.0, label: "A")
        var b = LectureBookmark(id: id, timestamp: 5.0, label: "A")
        #expect(a == b)

        b.label = "B"
        #expect(a != b)
    }
}

// MARK: - Lecture Tests

struct LectureTests {

    @Test func initWithDefaults() {
        let lecture = Lecture()
        #expect(lecture.title == "")
        #expect(lecture.duration == 0)
        #expect(lecture.audioFileName == nil)
        #expect(lecture.transcriptText == nil)
        #expect(lecture.transcriptSegments == nil)
        #expect(lecture.transcriptStatus == .notStarted)
        #expect(lecture.language == .english)
        #expect(lecture.bookmarks.isEmpty)
        #expect(lecture.courseName == nil)
        #expect(lecture.lastPlaybackPosition == nil)
    }

    @Test func initWithAudioPathExtractsFilename() {
        let url = URL(fileURLWithPath: "/some/path/recording_123.m4a")
        let lecture = Lecture(audioPath: url)
        #expect(lecture.audioFileName == "recording_123.m4a")
    }

    @Test func initWithNilAudioPath() {
        let lecture = Lecture(audioPath: nil)
        #expect(lecture.audioFileName == nil)
    }

    @Test func displayTitleWhenTitleIsEmpty() {
        let date = Date(timeIntervalSince1970: 1700000000) // Fixed date
        let lecture = Lecture(title: "", createdAt: date)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let expected = formatter.string(from: date)

        #expect(lecture.displayTitle == expected)
    }

    @Test func displayTitleWhenTitleExists() {
        let lecture = Lecture(title: "My Lecture")
        #expect(lecture.displayTitle == "My Lecture")
    }

    @Test func formattedDurationSeconds() {
        let lecture = Lecture(duration: 45)
        #expect(lecture.formattedDuration == "45s")
    }

    @Test func formattedDurationMinutes() {
        let lecture = Lecture(duration: 125) // 2m 5s
        #expect(lecture.formattedDuration == "2m 5s")
    }

    @Test func formattedDurationHours() {
        let lecture = Lecture(duration: 3661) // 1h 01m
        #expect(lecture.formattedDuration == "1h 01m")
    }

    @Test func formattedDurationZero() {
        let lecture = Lecture(duration: 0)
        #expect(lecture.formattedDuration == "0s")
    }

    @Test func wordCountWithText() {
        let lecture = Lecture(transcriptText: "Hello world this is a test")
        #expect(lecture.wordCount == 6)
    }

    @Test func wordCountWithNilText() {
        let lecture = Lecture(transcriptText: nil)
        #expect(lecture.wordCount == 0)
    }

    @Test func wordCountWithEmptyText() {
        let lecture = Lecture(transcriptText: "")
        #expect(lecture.wordCount == 0)
    }

    @Test func wordCountWithMultipleSpaces() {
        let lecture = Lecture(transcriptText: "  Hello   world  ")
        #expect(lecture.wordCount == 2)
    }

    @Test func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let bookmark = LectureBookmark(timestamp: 30.0, label: "Key Point")
        let segment = TranscriptionResult.TranscriptionSegment(
            startTime: 0, endTime: 5, text: "Hello world"
        )
        let original = Lecture(
            title: "Test Lecture",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            duration: 3600,
            transcriptText: "Hello world",
            transcriptSegments: [segment],
            transcriptStatus: .completed,
            language: .japanese,
            bookmarks: [bookmark],
            courseName: "CS101",
            lastPlaybackPosition: 120.5
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Lecture.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.duration == original.duration)
        #expect(decoded.transcriptText == original.transcriptText)
        #expect(decoded.transcriptStatus == original.transcriptStatus)
        #expect(decoded.language == original.language)
        #expect(decoded.bookmarks.count == 1)
        #expect(decoded.bookmarks.first?.label == "Key Point")
        #expect(decoded.courseName == "CS101")
        #expect(decoded.lastPlaybackPosition == 120.5)
        #expect(decoded.transcriptSegments?.count == 1)
    }

    @Test func decodeLegacyAudioPath() throws {
        // Simulate JSON from older version that stored full audioPath URL
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "Old Lecture",
            "createdAt": "2026-01-27T10:00:00Z",
            "duration": 600,
            "audioPath": "file:///var/mobile/Documents/recording_old.m4a",
            "transcriptStatus": "completed",
            "language": "en",
            "bookmarks": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let lecture = try decoder.decode(Lecture.self, from: Data(json.utf8))

        #expect(lecture.audioFileName == "recording_old.m4a")
        #expect(lecture.title == "Old Lecture")
        #expect(lecture.transcriptStatus == .completed)
    }

    @Test func decodeWithNewAudioFileName() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "New Lecture",
            "createdAt": "2026-03-01T10:00:00Z",
            "duration": 300,
            "audioFileName": "recording_new.m4a",
            "transcriptStatus": "not_started",
            "language": "ja",
            "bookmarks": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let lecture = try decoder.decode(Lecture.self, from: Data(json.utf8))

        #expect(lecture.audioFileName == "recording_new.m4a")
        #expect(lecture.language == .japanese)
    }

    @Test func decodeWithMissingOptionalFields() throws {
        // Minimal JSON — tests default values for optional fields
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "Minimal",
            "createdAt": "2026-01-01T00:00:00Z",
            "duration": 0,
            "bookmarks": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let lecture = try decoder.decode(Lecture.self, from: Data(json.utf8))

        #expect(lecture.audioFileName == nil)
        #expect(lecture.transcriptText == nil)
        #expect(lecture.transcriptSegments == nil)
        #expect(lecture.transcriptStatus == .notStarted)
        #expect(lecture.language == .english)
        #expect(lecture.courseName == nil)
        #expect(lecture.lastPlaybackPosition == nil)
    }

    @Test func encodeDoesNotIncludeLegacyAudioPath() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let lecture = Lecture(
            title: "Test",
            audioPath: URL(fileURLWithPath: "/path/recording.m4a")
        )

        let data = try encoder.encode(lecture)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["audioFileName"] as? String == "recording.m4a")
        #expect(dict["audioPath"] == nil) // Legacy key should not be encoded
    }

    @Test func equatable() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1700000000)
        let a = Lecture(id: id, title: "A", createdAt: date, duration: 100)
        let b = Lecture(id: id, title: "A", createdAt: date, duration: 100)
        #expect(a == b)

        let c = Lecture(id: id, title: "B", createdAt: date, duration: 100)
        #expect(a != c)
    }
}
