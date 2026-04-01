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
        // Info.plist から読み込み（xcconfig経由で設定される）
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              !urlString.hasPrefix("$("),  // 未展開の変数をチェック
              let url = URL(string: urlString) else {
            AppLogger.error("SUPABASE_URL is not configured. Please set it in xcconfig.", category: .general)
            preconditionFailure("SUPABASE_URL is not configured. Please set it in xcconfig.")
        }
        self.supabaseURL = url

        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {  // 未展開の変数をチェック
            AppLogger.error("SUPABASE_ANON_KEY is not configured. Please set it in xcconfig.", category: .general)
            preconditionFailure("SUPABASE_ANON_KEY is not configured. Please set it in xcconfig.")
        }
        self.supabaseAnonKey = key

        AppLogger.debug("Supabase config loaded", category: .general)
    }
}
