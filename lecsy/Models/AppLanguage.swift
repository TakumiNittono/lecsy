//
//  AppLanguage.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// アプリのUI言語設定（英語特化型）
enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    
    var displayName: String {
        return "English"
    }
    
    /// システムのデフォルト言語を取得（常に英語）
    static var systemDefault: AppLanguage {
        return .english
    }
}
