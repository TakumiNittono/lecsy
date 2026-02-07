//
//  lecsyApp.swift
//  lecsy
//
//  Created by Takuminittono on 2026/01/26.
//

import SwiftUI
import AuthenticationServices

@main
struct lecsyApp: App {
    @StateObject private var authService = AuthService.shared
    private let syncService = SyncService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                // Show ContentView if authenticated OR if user skipped login
                if authService.isAuthenticated || authService.hasSkippedLogin {
                    ContentView()
                        .task {
                            // Sync titles from Web on app launch (only if authenticated)
                            await syncTitlesOnLaunch()
                        }
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                // Universal Links のハンドリング（必要に応じて）
                if let url = userActivity.webpageURL {
                    print("🔗 lecsyApp: Universal Link received - \(url)")
                    handleIncomingURL(url)
                }
            }
        }
    }
    
    /// URLを処理（OAuth コールバック等）
    private func handleIncomingURL(_ url: URL) {
        print("🔗 lecsyApp: URL received - \(url)")
        print("   - scheme: \(url.scheme ?? "nil")")
        print("   - host: \(url.host ?? "nil")")
        print("   - path: \(url.path)")
        print("   - fragment: \(url.fragment ?? "nil")")
        
        // lecsy:// スキームの処理
        if url.scheme == "lecsy" {
            if url.host == "auth" || url.path.contains("callback") {
                print("🔗 lecsyApp: Processing authentication callback URL")
                Task { @MainActor in
                    await AuthService.shared.handleOAuthCallbackURL(url)
                }
            }
        }
    }
    
    /// Sync titles from Web on app launch
    @MainActor
    private func syncTitlesOnLaunch() async {
        // Execute only if authenticated
        guard await authService.isSessionValid else {
            print("⚠️ lecsyApp: Not authenticated, skipping title sync")
            return
        }
        
        print("🌐 lecsyApp: Starting title sync on launch")
        do {
            try await syncService.syncTitlesFromWeb()
            print("✅ lecsyApp: Title sync on launch completed")
        } catch {
            print("⚠️ lecsyApp: Title sync on launch failed - \(error.localizedDescription)")
            // Ignore errors (don't block app launch)
        }
    }
}
