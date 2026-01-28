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
    
    private init() {
        // Info.plist から読み込み（xcconfig経由で設定される）
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              !urlString.hasPrefix("$("),  // 未展開の変数をチェック
              let url = URL(string: urlString) else {
            fatalError("❌ SUPABASE_URL is not configured. Please set it in xcconfig.")
        }
        self.supabaseURL = url
        
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {  // 未展開の変数をチェック
            fatalError("❌ SUPABASE_ANON_KEY is not configured. Please set it in xcconfig.")
        }
        self.supabaseAnonKey = key
        
        #if DEBUG
        print("✅ Supabase URL loaded: \(urlString)")
        print("✅ Supabase Anon Key loaded (first 20 chars): \(key.prefix(20))...")
        #endif
    }
}
