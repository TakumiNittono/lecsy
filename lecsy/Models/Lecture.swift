//
//  Lecture.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// Lecture data model
struct Lecture: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var duration: TimeInterval // In seconds
    let audioPath: URL?
    var transcriptText: String?
    var transcriptStatus: TranscriptionStatus
    var savedToWeb: Bool
    var webTranscriptId: UUID?
    var language: TranscriptionLanguage
    
    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioPath: URL? = nil,
        transcriptText: String? = nil,
        transcriptStatus: TranscriptionStatus = .notStarted,
        savedToWeb: Bool = false,
        webTranscriptId: UUID? = nil,
        language: TranscriptionLanguage = .english
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.audioPath = audioPath
        self.transcriptText = transcriptText
        self.transcriptStatus = transcriptStatus
        self.savedToWeb = savedToWeb
        self.webTranscriptId = webTranscriptId
        self.language = language
    }
    
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
            return String(format: "%dh %dm", hours, minutes)
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
