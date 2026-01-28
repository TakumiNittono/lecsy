//
//  TranscriptionLanguage.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// 文字起こし言語
enum TranscriptionLanguage: String, Codable, CaseIterable {
    case auto = "auto"
    case japanese = "ja"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .auto:
            return "自動検出"
        case .japanese:
            return "日本語"
        case .english:
            return "English"
        }
    }
    
    var whisperLanguage: String? {
        switch self {
        case .auto:
            return nil // WhisperKitが自動検出
        case .japanese:
            return "ja"
        case .english:
            return "en"
        }
    }
}
