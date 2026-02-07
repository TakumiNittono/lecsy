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

/// Web sync service
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing: Bool = false
    @Published var pendingCount: Int = 0
    @Published var lastSyncError: String?
    
    private let authService = AuthService.shared
    private let lectureStore = LectureStore.shared
    
    // Use AuthService's supabase client (share session)
    private var supabase: SupabaseClient {
        return authService.supabase
    }
    
    private init() {
        // Check pending uploads on launch
        updatePendingCount()
    }
    
    /// Save to Web
    func saveToWeb(lecture: Lecture) async throws -> UUID {
        print("🌐 SyncService: Starting saveToWeb - Lecture ID: \(lecture.id)")
        
        guard await authService.isSessionValid else {
            print("❌ SyncService: Not authenticated")
            throw SyncError.notAuthenticated
        }
        
        guard let transcriptText = lecture.transcriptText, !transcriptText.isEmpty else {
            print("❌ SyncService: No transcript text available")
            throw SyncError.noTranscript
        }
        
        isSyncing = true
        lastSyncError = nil
        
        defer {
            isSyncing = false
            updatePendingCount()
        }
        
        do {
            // Call Edge Function
            // Convert created_at to ISO 8601 format string
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
            
            print("🌐 SyncService: Calling Edge Function...")
            print("   - Title: \(request.title)")
            print("   - Content length: \(request.content.count) characters")
            print("   - Language: \(request.language ?? "nil")")
            let config = SupabaseConfig.shared
            print("   - URL: \(config.supabaseURL.absoluteString)/functions/v1/save-transcript")
            
            // Retry logic (max 3 times)
            var lastError: Error?
            let maxRetries = 3
            let retryDelay: TimeInterval = 2.0 // 2 seconds
            
            for attempt in 1...maxRetries {
                do {
                    // Check if session is valid
                    guard await authService.isSessionValid else {
                        print("⚠️ SyncService: Session is invalid")
                        throw SyncError.notAuthenticated
                    }
                    
                    // Refresh session to get latest token
                    print("🌐 SyncService: Refreshing session...")
                    let refreshSuccess = await authService.refreshSession()
                    if !refreshSuccess {
                        print("⚠️ SyncService: Session refresh failed")
                        // リフレッシュ失敗でもアクセストークンが有効かもしれないので続行
                    }
                    
                    // Get access token (refreshSession()でキャッシュされた最新トークンを取得)
                    guard let accessToken = await authService.accessToken else {
                        print("⚠️ SyncService: Cannot get access token")
                        throw SyncError.notAuthenticated
                    }
                    
                    // トークンのデバッグ情報を出力
                    AppLogger.logToken("Access Token", token: accessToken, category: .sync)
                    
                    // Call Edge Function using URLRequest directly
                    // Explicitly set Authorization header
                    let config = SupabaseConfig.shared
                    let functionURL = config.supabaseURL.appendingPathComponent("functions/v1/save-transcript")
                    
                    var urlRequest = URLRequest(url: functionURL)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // Set in Bearer token format (ensure Bearer prefix is not already included)
                    let authHeader = accessToken.hasPrefix("Bearer ") ? accessToken : "Bearer \(accessToken)"
                    urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
                    
                    // Supabase Edge Functionsでは、apikeyヘッダーも必要かもしれない
                    urlRequest.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                    
                    AppLogger.debug("Authorization header configured", category: .sync)
                    print("🌐 SyncService: Headers configured - Authorization: \(authHeader.prefix(30))..., apikey: \(config.supabaseAnonKey.prefix(20))...")
                    
                    let encoder = JSONEncoder()
                    urlRequest.httpBody = try encoder.encode(request)
                    
                    print("🌐 SyncService: Sending HTTP request...")
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw SyncError.uploadFailed("Invalid response type")
                    }
                    
                    print("🌐 SyncService: HTTP response received - Status: \(httpResponse.statusCode)")
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Parse error response to get detailed error message
                        var errorMessage = "Unknown error"
                        if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                           let message = errorData["message"] ?? errorData["error"] {
                            errorMessage = message
                        } else if let errorString = String(data: data, encoding: .utf8) {
                            errorMessage = errorString
                        }
                        print("❌ SyncService: HTTP error - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
                        throw SyncError.uploadFailed("Edge Function returned a non-2xx status code: \(httpResponse.statusCode)")
                    }
                    
                    let decoder = JSONDecoder()
                    let responseData: SaveTranscriptResponse = try decoder.decode(SaveTranscriptResponse.self, from: data)
                    
                    print("✅ SyncService: Web save successful - Web ID: \(responseData.id)")
                    
                    // Mark as saved
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
                    
                    // If 401 error and max retries reached
                    if errorMessage.contains("401") || errorMessage.contains("Unauthorized") || errorMessage.contains("Invalid JWT") {
                        print("⚠️ SyncService: Stopping retry due to authentication error")
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
    
    /// Retry pending uploads
    func retryPendingUploads() async {
        let pendingLectures = lectureStore.getPendingUploads()
        
        guard !pendingLectures.isEmpty else {
            print("🌐 SyncService: No pending uploads")
            return
        }
        
        print("🌐 SyncService: Retrying pending uploads - \(pendingLectures.count) items")
        isSyncing = true
        
        var successCount = 0
        var failureCount = 0
        
        for (index, lecture) in pendingLectures.enumerated() {
            print("🌐 SyncService: [\(index + 1)/\(pendingLectures.count)] Uploading...")
            do {
                _ = try await saveToWeb(lecture: lecture)
                successCount += 1
            } catch {
                print("❌ SyncService: Upload failed for lecture \(lecture.id): \(error)")
                failureCount += 1
                // Continue with next lecture even if error occurs
            }
        }
        
        isSyncing = false
        updatePendingCount()
        print("🌐 SyncService: Retry completed - Success: \(successCount), Failed: \(failureCount)")
    }
    
    /// 保留中の数を更新
    private func updatePendingCount() {
        pendingCount = lectureStore.getPendingUploads().count
    }
    
    /// Web側のタイトルを更新
    func updateTitleOnWeb(lecture: Lecture, newTitle: String) async throws {
        guard let webId = lecture.webTranscriptId else {
            print("⚠️ SyncService: No Web ID - Skipping title update")
            return
        }
        
        guard await authService.isSessionValid else {
            print("❌ SyncService: Not authenticated")
            throw SyncError.notAuthenticated
        }
        
        print("🌐 SyncService: Starting Web title update - Web ID: \(webId)")
        
        // Refresh session to get latest token
        await authService.refreshSession()
        
        guard let accessToken = await authService.accessToken else {
            print("⚠️ SyncService: Cannot get access token")
            throw SyncError.notAuthenticated
        }
        
        // Call Web API to update title
        let config = SupabaseConfig.shared
        // Use Web app API endpoint
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
            print("✅ SyncService: Web title update successful")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ SyncService: Web title update failed - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
            throw SyncError.uploadFailed("Failed to update title: \(errorMessage)")
        }
    }
    
    /// Get latest titles from Web and update iOS app lectures
    func syncTitlesFromWeb() async throws {
        guard await authService.isSessionValid else {
            print("⚠️ SyncService: 認証されていません - タイトル同期をスキップ")
            return
        }
        
        print("🌐 SyncService: Webからタイトル同期開始")
        
        // セッションをリフレッシュして最新のトークンを取得
        await authService.refreshSession()
        
        guard let accessToken = await authService.accessToken else {
            print("⚠️ SyncService: アクセストークンが取得できません")
            throw SyncError.notAuthenticated
        }
        
        // Supabase REST APIからtranscriptsを取得
        let config = SupabaseConfig.shared
        let baseURL = config.supabaseURL.appendingPathComponent("rest/v1/transcripts")
        
        // URLにクエリパラメータを追加（apikeyはヘッダーに設定するため、クエリパラメータには含めない）
        var urlComponents = URLComponents(string: baseURL.absoluteString)!
        urlComponents.queryItems = [
            URLQueryItem(name: "select", value: "id,title,updated_at"),
            URLQueryItem(name: "order", value: "updated_at.desc")
        ]
        
        guard let restURL = urlComponents.url else {
            throw SyncError.uploadFailed("Failed to create REST API URL")
        }
        
        var urlRequest = URLRequest(url: restURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        // Supabase REST APIは、認証済みリクエストの場合、Authorizationヘッダーとapikeyヘッダーの両方が必要
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.uploadFailed("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            // レスポンスデータを確認
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 SyncService: レスポンスデータ - \(responseString.prefix(200))...")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let transcripts: [WebTranscript]
            do {
                transcripts = try decoder.decode([WebTranscript].self, from: data)
                print("✅ SyncService: Webから \(transcripts.count) 件のtranscriptsを取得")
            } catch {
                print("❌ SyncService: JSONデコードエラー - \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("   - Type mismatch: \(type), Context: \(context)")
                    case .valueNotFound(let type, let context):
                        print("   - Value not found: \(type), Context: \(context)")
                    case .keyNotFound(let key, let context):
                        print("   - Key not found: \(key), Context: \(context)")
                    case .dataCorrupted(let context):
                        print("   - Data corrupted: \(context)")
                    @unknown default:
                        print("   - Unknown decoding error")
                    }
                }
                // 空の配列を返してエラーを無視（タイトル同期はオプショナルな機能）
                print("⚠️ SyncService: タイトル同期をスキップします")
                return
            }
            
            // 各transcriptのタイトルをiOSアプリの講義に反映
            var updatedCount = 0
            for transcript in transcripts {
                // webTranscriptIdが一致する講義を探す
                if let lecture = lectureStore.lectures.first(where: { $0.webTranscriptId == transcript.id }) {
                    // タイトルが異なる場合のみ更新
                    let webTitle = transcript.displayTitle
                    if lecture.title != webTitle {
                        var updatedLecture = lecture
                        updatedLecture.title = webTitle
                        lectureStore.updateLecture(updatedLecture)
                        updatedCount += 1
                        print("✅ SyncService: タイトル更新 - ID: \(transcript.id), Title: \(webTitle)")
                    }
                }
            }
            
            print("✅ SyncService: タイトル同期完了 - \(updatedCount) 件更新")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ SyncService: Webタイトル取得失敗 - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
            throw SyncError.uploadFailed("Failed to fetch titles: \(errorMessage)")
        }
    }
}

/// Save request
struct SaveTranscriptRequest: Codable {
    let title: String
    let content: String
    let created_at: String  // ISO 8601 format string
    let duration: TimeInterval?
    let language: String?
    let app_version: String
}

/// Save response
struct SaveTranscriptResponse: Codable {
    let id: UUID
    let created_at: String?  // Optional (returned from Edge Function but not used)
}

/// Transcript information retrieved from Web
struct WebTranscript: Codable {
    let id: UUID
    let title: String?
    let updated_at: Date?
    
    var displayTitle: String {
        return title ?? ""
    }
}

/// Sync error
enum SyncError: LocalizedError {
    case notAuthenticated
    case noTranscript
    case uploadFailed(String)
    case notSavedToWeb
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noTranscript:
            return "No transcript data available"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .notSavedToWeb:
            return "Not saved to Web"
        }
    }
}

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
