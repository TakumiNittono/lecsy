//
//  TranscriptionResult.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// Transcription result
struct TranscriptionResult: Codable, Equatable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
    let processingTime: TimeInterval

    struct TranscriptionSegment: Codable, Identifiable, Equatable {
        var id: String { "\(startTime)-\(endTime)" }
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String

        /// Cleaned text with Whisper tokens removed
        var cleanText: String {
            Self.stripWhisperTokens(text)
        }

        private enum CodingKeys: String, CodingKey {
            case startTime, endTime, text
        }

        /// Remove Whisper special tokens from text
        static func stripWhisperTokens(_ input: String) -> String {
            // Remove all <|...|> style tokens (e.g. <|startoftranscript|>, <|en|>, <|0.00|>)
            let cleaned = input.replacingOccurrences(
                of: "<\\|[^|]*\\|>",
                with: "",
                options: .regularExpression
            )
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Cleaned full text with Whisper tokens removed
    var cleanText: String {
        TranscriptionSegment.stripWhisperTokens(text)
    }
}
