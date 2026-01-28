//
//  AppLanguage.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// アプリのUI言語設定
enum AppLanguage: String, Codable, CaseIterable {
    case japanese = "ja"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .japanese:
            return "日本語"
        case .english:
            return "English"
        }
    }
    
    /// システムのデフォルト言語を取得
    static var systemDefault: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        } else {
            return .english
        }
    }
}
