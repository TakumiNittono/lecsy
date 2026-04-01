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

        private enum CodingKeys: String, CodingKey {
            case startTime, endTime, text
        }
    }
}
