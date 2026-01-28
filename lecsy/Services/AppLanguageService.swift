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
        // 保存された言語設定を読み込み、なければシステムデフォルトを使用
        if let savedLanguageRaw = UserDefaults.standard.string(forKey: "appLanguage"),
           let savedLanguage = AppLanguage(rawValue: savedLanguageRaw) {
            currentLanguage = savedLanguage
        } else {
            currentLanguage = AppLanguage.systemDefault
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    /// 言語を設定
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}
