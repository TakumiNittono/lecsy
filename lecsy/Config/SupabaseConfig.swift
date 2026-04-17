//
//  SupabaseConfig.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// Supabase設定管理
struct SupabaseConfig {
    static let shared = SupabaseConfig()

    let supabaseURL: URL
    let supabaseAnonKey: String

    /// Web app base URL (for API calls and share links)
    static let webBaseURL: URL = {
        guard let url = URL(string: "https://lecsy.app") else {
            preconditionFailure("Invalid web base URL")
        }
        return url
    }()
    
    private init() {
        // Info.plist から読み込み（xcconfig経由で設定される）。
        // Release ビルドで値が欠けていた場合は、起動クラッシュさせず
        // プレースホルダに落として後続のネットワーク呼び出しで失敗させる。
        // （App Store 審査で設定事故があっても即リジェクトされない保険）
        let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        if let urlString, !urlString.isEmpty, !urlString.hasPrefix("$("), let url = URL(string: urlString) {
            self.supabaseURL = url
        } else {
            AppLogger.error("SUPABASE_URL is not configured. Please set it in xcconfig.", category: .general)
            assertionFailure("SUPABASE_URL is not configured. Please set it in xcconfig.")
            self.supabaseURL = URL(string: "https://invalid.supabase.local")!
        }

        let keyString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        if let keyString, !keyString.isEmpty, !keyString.hasPrefix("$(") {
            self.supabaseAnonKey = keyString
        } else {
            AppLogger.error("SUPABASE_ANON_KEY is not configured. Please set it in xcconfig.", category: .general)
            assertionFailure("SUPABASE_ANON_KEY is not configured. Please set it in xcconfig.")
            self.supabaseAnonKey = ""
        }

        AppLogger.debug("Supabase config loaded", category: .general)
    }
}
