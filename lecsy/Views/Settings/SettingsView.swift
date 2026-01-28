//
//  SettingsView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared
    @StateObject private var appLanguageService = AppLanguageService.shared
    @StateObject private var lectureStore = LectureStore.shared
    
    @State private var showSignInSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // アカウントセクション
                Section("アカウント") {
                    if authService.isAuthenticated {
                        if let user = authService.currentUser {
                            HStack {
                                Text("ログイン中:")
                                Spacer()
                                Text(user.email ?? "不明")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("ログアウト", role: .destructive) {
                            Task {
                                try? await authService.signOut()
                            }
                        }
                    } else {
                        Button("Sign In") {
                            showSignInSheet = true
                        }
                    }
                }
                
                // アプリ言語設定
                Section("アプリ言語") {
                    HStack {
                        Text("表示言語")
                        Spacer()
                        Picker("表示言語", selection: $appLanguageService.currentLanguage) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: appLanguageService.currentLanguage) { oldValue, newValue in
                            appLanguageService.setLanguage(newValue)
                        }
                    }
                }
                
                // 文字起こし言語設定
                Section("音声検出言語") {
                    HStack {
                        Text("検出言語")
                        Spacer()
                        Picker("検出言語", selection: $transcriptionService.transcriptionLanguage) {
                            ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: transcriptionService.transcriptionLanguage) { oldValue, newValue in
                            transcriptionService.setLanguage(newValue)
                        }
                    }
                    
                    // 言語設定の説明
                    Text("日本語を選択すると、日本語として確実に検出されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // モデル情報
                    if transcriptionService.isModelLoaded {
                        HStack {
                            Text("Model Status")
                            Spacer()
                            Text("Loaded")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("モデルサイズ")
                            Spacer()
                            Text(formatBytes(transcriptionService.modelSize))
                                .foregroundColor(.secondary)
                        }
                        
                        Button("モデルを削除", role: .destructive) {
                            Task {
                                try? transcriptionService.deleteModel()
                            }
                        }
                    } else {
                        HStack {
                            Text("Model Status")
                            Spacer()
                            Text("Not Loaded")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 同期セクション
                Section("同期") {
                    if authService.isAuthenticated {
                        HStack {
                            Text("保留中のアップロード")
                            Spacer()
                            if syncService.pendingCount > 0 {
                                Text("\(syncService.pendingCount)")
                                    .foregroundColor(.orange)
                            } else {
                                Text("なし")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if syncService.pendingCount > 0 {
                            Button("Retry Uploads") {
                                Task {
                                    await syncService.retryPendingUploads()
                                }
                            }
                        }
                        
                        if let error = syncService.lastSyncError {
                            Text("最後のエラー: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("Sign in to sync with web")
                            .foregroundColor(.secondary)
                    }
                }
                
                // ストレージ情報
                Section("ストレージ") {
                    HStack {
                        Text("講義の総数")
                        Spacer()
                        Text("\(lectureStore.lectures.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    let totalSize = lectureStore.lectures.reduce(0) { total, lecture in
                        total + (lecture.audioPath.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int64 } ?? 0)
                    }
                    
                    HStack {
                        Text("合計サイズ")
                        Spacer()
                        Text(formatBytes(totalSize))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSignInSheet) {
                SignInSheet()
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Webアプリと講義を同期するにはログインしてください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                try await authService.signInWithGoogle()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Googleでログイン")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        print("🍎 SettingsView: Apple Sign In button tapped")
                        Task {
                            isLoading = true
                            errorMessage = nil
                            print("🍎 SettingsView: Starting Apple Sign In...")
                            do {
                                try await authService.signInWithApple()
                                print("🍎 SettingsView: Apple Sign In completed")
                            } catch {
                                print("🍎 SettingsView: Apple Sign In error - \(error.localizedDescription)")
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
