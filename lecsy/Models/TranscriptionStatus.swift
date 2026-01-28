//
//  TranscriptionStatus.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// 文字起こし状態
enum TranscriptionStatus: String, Codable {
    case notStarted = "not_started"
    case downloading = "downloading"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .downloading:
            return "Downloading Model"
        case .processing:
            return "Transcribing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}
