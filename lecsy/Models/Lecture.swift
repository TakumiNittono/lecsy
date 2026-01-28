//
//  Lecture.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// 講義データモデル
struct Lecture: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var duration: TimeInterval // 秒単位
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
        language: TranscriptionLanguage = .auto
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
    
    /// タイトルが空の場合のデフォルトタイトル
    var displayTitle: String {
        if title.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }
        return title
    }
    
    /// 時間をフォーマット（例: "1h 23m"）
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
    
    /// 単語数を計算
    var wordCount: Int {
        guard let text = transcriptText else { return 0 }
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
