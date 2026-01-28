//
//  SyncService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import Supabase
import Combine
import os.log

/// Web同期サービス
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing: Bool = false
    @Published var pendingCount: Int = 0
    @Published var lastSyncError: String?
    
    private let authService = AuthService.shared
    private let lectureStore = LectureStore.shared
    
    // AuthServiceのsupabaseクライアントを使用（セッションを共有）
    private var supabase: SupabaseClient {
        return authService.supabase
    }
    
    private init() {
        // 起動時に保留中のアップロードを確認
        updatePendingCount()
    }
    
    /// Webに保存
    func saveToWeb(lecture: Lecture) async throws -> UUID {
        print("🌐 SyncService: saveToWeb開始 - Lecture ID: \(lecture.id)")
        
        guard await authService.isSessionValid else {
            print("❌ SyncService: 認証されていません")
            throw SyncError.notAuthenticated
        }
        
        guard let transcriptText = lecture.transcriptText, !transcriptText.isEmpty else {
            print("❌ SyncService: 文字起こしテキストがありません")
            throw SyncError.noTranscript
        }
        
        isSyncing = true
        lastSyncError = nil
        
        defer {
            isSyncing = false
            updatePendingCount()
        }
        
        do {
            // Edge Functionを呼び出し
            // created_atをISO 8601形式の文字列に変換
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let created_at_string = iso8601Formatter.string(from: lecture.createdAt)
            
            let request = SaveTranscriptRequest(
                title: lecture.displayTitle,
                content: transcriptText,
                created_at: created_at_string,
                duration: lecture.duration,
                language: lecture.language.rawValue,
                app_version: Bundle.main.appVersion ?? "1.0.0"
            )
            
            print("🌐 SyncService: Edge Function呼び出し中...")
            print("   - Title: \(request.title)")
            print("   - Content length: \(request.content.count) characters")
            print("   - Language: \(request.language ?? "nil")")
            let config = SupabaseConfig.shared
            print("   - URL: \(config.supabaseURL.absoluteString)/functions/v1/save-transcript")
            
            // リトライロジック（最大3回）
            var lastError: Error?
            let maxRetries = 3
            let retryDelay: TimeInterval = 2.0 // 2秒
            
            for attempt in 1...maxRetries {
                do {
                    // セッションが有効か確認
                    guard await authService.isSessionValid else {
                        print("⚠️ SyncService: セッションが無効です")
                        throw SyncError.notAuthenticated
                    }
                    
                    // 常にセッションをリフレッシュして、最新のトークンを取得
                    print("🌐 SyncService: セッションをリフレッシュ中...")
                    await authService.refreshSession()
                    // リフレッシュ後にセッションが有効か再確認
                    guard await authService.isSessionValid else {
                        print("⚠️ SyncService: セッションリフレッシュ後も無効です")
                        throw SyncError.notAuthenticated
                    }
                    
                    // アクセストークンを取得
                    guard let accessToken = await authService.accessToken else {
                        print("⚠️ SyncService: アクセストークンが取得できません")
                        throw SyncError.notAuthenticated
                    }
                    
                    AppLogger.logToken("Access Token", token: accessToken, category: .sync)
                    
                    // URLRequestを直接使用してEdge Functionを呼び出し
                    // Authorizationヘッダーを明示的に設定
                    let config = SupabaseConfig.shared
                    let functionURL = config.supabaseURL.appendingPathComponent("functions/v1/save-transcript")
                    
                    var urlRequest = URLRequest(url: functionURL)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // Bearerトークンの形式で設定（既にBearerプレフィックスが含まれていないことを確認）
                    let authHeader = accessToken.hasPrefix("Bearer ") ? accessToken : "Bearer \(accessToken)"
                    urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
                    AppLogger.debug("Authorization header configured", category: .sync)
                    
                    let encoder = JSONEncoder()
                    urlRequest.httpBody = try encoder.encode(request)
                    
                    print("🌐 SyncService: HTTPリクエスト送信...")
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw SyncError.uploadFailed("Invalid response type")
                    }
                    
                    print("🌐 SyncService: HTTPレスポンス受信 - Status: \(httpResponse.statusCode)")
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        // エラーレスポンスをパースして詳細なエラーメッセージを取得
                        var errorMessage = "Unknown error"
                        if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                           let message = errorData["message"] ?? errorData["error"] {
                            errorMessage = message
                        } else if let errorString = String(data: data, encoding: .utf8) {
                            errorMessage = errorString
                        }
                        print("❌ SyncService: HTTPエラー - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
                        throw SyncError.uploadFailed("Edge Function returned a non-2xx status code: \(httpResponse.statusCode)")
                    }
                    
                    let decoder = JSONDecoder()
                    let responseData: SaveTranscriptResponse = try decoder.decode(SaveTranscriptResponse.self, from: data)
                    
                    print("✅ SyncService: Web保存成功 - Web ID: \(responseData.id)")
                    
                    // 保存成功をマーク
                    lectureStore.markAsSavedToWeb(lecture, webId: responseData.id)
                    
                    return responseData.id
                } catch {
                    lastError = error
                    let errorMessage = error.localizedDescription
                    print("❌ SyncService: Web保存エラー (試行 \(attempt)/\(maxRetries)) - \(errorMessage)")
                    
                    // 401エラー（認証エラー）の場合、セッションをリフレッシュして再試行
                    if (errorMessage.contains("401") || errorMessage.contains("Unauthorized") || errorMessage.contains("Invalid JWT")) && attempt < maxRetries {
                        print("⚠️ SyncService: 認証エラーが発生しました。セッションをリフレッシュして再試行します...")
                        await authService.refreshSession()
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }
                    
                    // 401エラーで最大試行回数に達した場合
                    if errorMessage.contains("401") || errorMessage.contains("Unauthorized") || errorMessage.contains("Invalid JWT") {
                        print("⚠️ SyncService: 認証エラーのためリトライを中止します")
                        break
                    }
                    
                    if let urlError = error as? URLError {
                        print("   - URL Error Code: \(urlError.code.rawValue)")
                        print("   - URL Error Description: \(urlError.localizedDescription)")
                        
                        // ネットワークエラーの場合のみリトライ
                        if urlError.code == .networkConnectionLost || 
                           urlError.code == .timedOut ||
                           urlError.code == .notConnectedToInternet {
                            
                            if attempt < maxRetries {
                                print("🌐 SyncService: \(retryDelay)秒後にリトライします...")
                                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                                continue
                            }
                        }
                    }
                    
                    // その他のエラーもリトライを試みる（サーバーエラーなど）
                    if attempt < maxRetries {
                        print("🌐 SyncService: \(retryDelay)秒後にリトライします...")
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }
                    
                    // 最大試行回数に達した場合
                    break
                }
            }
            
            // すべてのリトライが失敗した場合
            let errorMessage = lastError?.localizedDescription ?? "Unknown error"
            print("❌ SyncService: Web保存失敗（全\(maxRetries)回の試行が失敗）")
            lastSyncError = errorMessage
            throw SyncError.uploadFailed(errorMessage)
        } catch {
            let errorMessage = error.localizedDescription
            print("❌ SyncService: Web保存エラー - \(errorMessage)")
            if let urlError = error as? URLError {
                print("   - URL Error Code: \(urlError.code.rawValue)")
                print("   - URL Error Description: \(urlError.localizedDescription)")
            }
            lastSyncError = errorMessage
            throw SyncError.uploadFailed(errorMessage)
        }
    }
    
    /// 保留中のアップロードを再試行
    func retryPendingUploads() async {
        let pendingLectures = lectureStore.getPendingUploads()
        
        guard !pendingLectures.isEmpty else {
            print("🌐 SyncService: 保留中のアップロードはありません")
            return
        }
        
        print("🌐 SyncService: 保留中のアップロードを再試行 - \(pendingLectures.count)件")
        isSyncing = true
        
        var successCount = 0
        var failureCount = 0
        
        for (index, lecture) in pendingLectures.enumerated() {
            print("🌐 SyncService: [\(index + 1)/\(pendingLectures.count)] アップロード中...")
            do {
                _ = try await saveToWeb(lecture: lecture)
                successCount += 1
            } catch {
                print("❌ SyncService: 講義 \(lecture.id) のアップロードに失敗: \(error)")
                failureCount += 1
                // エラーが発生しても次の講義のアップロードを試行
            }
        }
        
        isSyncing = false
        updatePendingCount()
        print("🌐 SyncService: 再試行完了 - 成功: \(successCount), 失敗: \(failureCount)")
    }
    
    /// 保留中の数を更新
    private func updatePendingCount() {
        pendingCount = lectureStore.getPendingUploads().count
    }
    
    /// Web側のタイトルを更新
    func updateTitleOnWeb(lecture: Lecture, newTitle: String) async throws {
        guard let webId = lecture.webTranscriptId else {
            print("⚠️ SyncService: Web IDがありません - タイトル更新をスキップ")
            return
        }
        
        guard await authService.isSessionValid else {
            print("❌ SyncService: 認証されていません")
            throw SyncError.notAuthenticated
        }
        
        print("🌐 SyncService: Webタイトル更新開始 - Web ID: \(webId)")
        
        // セッションをリフレッシュして最新のトークンを取得
        await authService.refreshSession()
        
        guard let accessToken = await authService.accessToken else {
            print("⚠️ SyncService: アクセストークンが取得できません")
            throw SyncError.notAuthenticated
        }
        
        // Web APIを呼び出してタイトルを更新
        let config = SupabaseConfig.shared
        // WebアプリのAPIエンドポイントを使用
        guard let webBaseURL = URL(string: "https://lecsy.vercel.app") else {
            throw SyncError.uploadFailed("Invalid web URL")
        }
        let updateURL = webBaseURL.appendingPathComponent("api/transcripts/\(webId.uuidString)/title")
        
        var urlRequest = URLRequest(url: updateURL)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ["title": newTitle]
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.uploadFailed("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            print("✅ SyncService: Webタイトル更新成功")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ SyncService: Webタイトル更新失敗 - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
            throw SyncError.uploadFailed("Failed to update title: \(errorMessage)")
        }
    }
}

/// 保存リクエスト
struct SaveTranscriptRequest: Codable {
    let title: String
    let content: String
    let created_at: String  // ISO 8601形式の文字列
    let duration: TimeInterval?
    let language: String?
    let app_version: String
}

/// 保存レスポンス
struct SaveTranscriptResponse: Codable {
    let id: UUID
    let created_at: String?  // オプショナル（Edge Functionから返されるが、使用しない）
}

/// 同期エラー
enum SyncError: LocalizedError {
    case notAuthenticated
    case noTranscript
    case uploadFailed(String)
    case notSavedToWeb
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "ユーザーが認証されていません"
        case .noTranscript:
            return "文字起こしデータがありません"
        case .uploadFailed(let message):
            return "アップロードに失敗しました: \(message)"
        case .notSavedToWeb:
            return "Webに保存されていません"
        }
    }
}

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
