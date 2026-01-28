//
//  TranscriptionResult.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// 文字起こし結果
struct TranscriptionResult: Codable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
    let processingTime: TimeInterval
    
    struct TranscriptionSegment: Codable {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }
}
