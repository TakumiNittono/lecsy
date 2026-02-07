//
//  TranscriptionLanguage.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// 文字起こし言語（英語特化型）
enum TranscriptionLanguage: String, Codable, CaseIterable {
    case english = "en"
    
    var displayName: String {
        return "English"
    }
    
    var whisperLanguage: String? {
        return "en" // 常に英語として処理
    }
}
