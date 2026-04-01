//
//  AppLanguageService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import Combine

/// アプリのUI言語を管理するサービス
@MainActor
class AppLanguageService: ObservableObject {
    static let shared = AppLanguageService()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    private init() {
        // 英語特化型：常に英語を使用
        currentLanguage = .english
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        AppLogger.debug("AppLanguage: English-only mode", category: .general)
    }
    
    /// 言語を設定
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}
