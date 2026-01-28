//
//  lecsyApp.swift
//  lecsy
//
//  Created by Takuminittono on 2026/01/26.
//

import SwiftUI

@main
struct lecsyApp: App {
    @StateObject private var authService = AuthService.shared
    private let syncService = SyncService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    ContentView()
                        .task {
                            // アプリ起動時にWebからタイトルを同期
                            await syncTitlesOnLaunch()
                        }
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                // URLスキーム処理（認証コールバック）
                print("🔗 lecsyApp: URL受信 - \(url)")
                if url.scheme == "lecsy" && url.host == "auth" {
                    print("🔗 lecsyApp: 認証コールバックURLを処理")
                    Task { @MainActor in
                        // AuthServiceでコールバックURLを処理
                        await AuthService.shared.handleOAuthCallbackURL(url)
                    }
                }
            }
        }
    }
    
    /// アプリ起動時にWebからタイトルを同期
    @MainActor
    private func syncTitlesOnLaunch() async {
        // 認証されている場合のみ実行
        guard await authService.isSessionValid else {
            print("⚠️ lecsyApp: 認証されていないためタイトル同期をスキップ")
            return
        }
        
        print("🌐 lecsyApp: 起動時タイトル同期開始")
        do {
            try await syncService.syncTitlesFromWeb()
            print("✅ lecsyApp: 起動時タイトル同期完了")
        } catch {
            print("⚠️ lecsyApp: 起動時タイトル同期失敗 - \(error.localizedDescription)")
            // エラーは無視（アプリの起動を妨げない）
        }
    }
}
