//
//  Lecture.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// Bookmark within a lecture recording
struct LectureBookmark: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: TimeInterval
    var label: String

    init(id: UUID = UUID(), timestamp: TimeInterval, label: String = "Bookmark") {
        self.id = id
        self.timestamp = timestamp
        self.label = label
    }
}

/// Lecture data model
struct Lecture: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var duration: TimeInterval // In seconds
    var audioFileName: String? // Store only filename, not absolute path
    var transcriptText: String?
    var transcriptSegments: [TranscriptionResult.TranscriptionSegment]?
    var transcriptStatus: TranscriptionStatus
    var language: TranscriptionLanguage
    var bookmarks: [LectureBookmark]
    var courseName: String?
    var lastPlaybackPosition: TimeInterval?

    /// Resolved audio file URL (reconstructed from filename + Documents directory)
    var audioPath: URL? {
        guard let fileName = audioFileName,
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = documentsPath.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioPath: URL? = nil,
        transcriptText: String? = nil,
        transcriptSegments: [TranscriptionResult.TranscriptionSegment]? = nil,
        transcriptStatus: TranscriptionStatus = .notStarted,
        language: TranscriptionLanguage = .english,
        bookmarks: [LectureBookmark] = [],
        courseName: String? = nil,
        lastPlaybackPosition: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioPath?.lastPathComponent
        self.transcriptText = transcriptText
        self.transcriptSegments = transcriptSegments
        self.transcriptStatus = transcriptStatus
        self.language = language
        self.bookmarks = bookmarks
        self.courseName = courseName
        self.lastPlaybackPosition = lastPlaybackPosition
    }

    // MARK: - Custom Codable (handles migration from old audioPath URL to new audioFileName)

    enum CodingKeys: String, CodingKey {
        case id, title, createdAt, duration
        case audioFileName
        case audioPath // legacy key for migration
        case transcriptText, transcriptSegments, transcriptStatus
        case language, bookmarks, courseName
        case lastPlaybackPosition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)

        // Migration: try new audioFileName first, then fall back to old audioPath URL
        if let fileName = try container.decodeIfPresent(String.self, forKey: .audioFileName) {
            audioFileName = fileName
        } else if let legacyURL = try container.decodeIfPresent(URL.self, forKey: .audioPath) {
            // Extract filename from old absolute path
            audioFileName = legacyURL.lastPathComponent
        } else {
            audioFileName = nil
        }

        transcriptText = try container.decodeIfPresent(String.self, forKey: .transcriptText)
        transcriptSegments = try container.decodeIfPresent([TranscriptionResult.TranscriptionSegment].self, forKey: .transcriptSegments)
        transcriptStatus = try container.decodeIfPresent(TranscriptionStatus.self, forKey: .transcriptStatus) ?? .notStarted
        language = try container.decodeIfPresent(TranscriptionLanguage.self, forKey: .language) ?? .english
        bookmarks = try container.decodeIfPresent([LectureBookmark].self, forKey: .bookmarks) ?? []
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        lastPlaybackPosition = try container.decodeIfPresent(TimeInterval.self, forKey: .lastPlaybackPosition)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(audioFileName, forKey: .audioFileName)
        // Don't encode legacy audioPath key — only audioFileName going forward
        try container.encodeIfPresent(transcriptText, forKey: .transcriptText)
        try container.encodeIfPresent(transcriptSegments, forKey: .transcriptSegments)
        try container.encode(transcriptStatus, forKey: .transcriptStatus)
        try container.encode(language, forKey: .language)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encodeIfPresent(courseName, forKey: .courseName)
        try container.encodeIfPresent(lastPlaybackPosition, forKey: .lastPlaybackPosition)
    }

    // MARK: - Computed properties

    /// Default title when title is empty
    var displayTitle: String {
        if title.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }
        return title
    }

    /// Format duration (e.g., "1h 23m")
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Calculate word count
    var wordCount: Int {
        guard let text = transcriptText else { return 0 }
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
