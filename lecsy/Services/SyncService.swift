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
        AppLogger.debug("SyncService: Starting saveToWeb - Lecture ID: \(lecture.id)", category: .sync)
        
        guard await authService.isSessionValid else {
            AppLogger.error("SyncService: Not authenticated", category: .sync)
            throw SyncError.notAuthenticated
        }

        guard let transcriptText = lecture.transcriptText, !transcriptText.isEmpty else {
            AppLogger.error("SyncService: No transcript text available", category: .sync)
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
            
            AppLogger.debug("SyncService: Calling Edge Function...", category: .sync)
            AppLogger.debug("SyncService: Title: \(request.title), Content length: \(request.content.count) characters, Language: \(request.language ?? "nil")", category: .sync)
            let config = SupabaseConfig.shared
            AppLogger.debug("SyncService: URL: \(config.supabaseURL.absoluteString)/functions/v1/save-transcript", category: .sync)
            
            // Retry logic (max 3 times)
            var lastError: Error?
            var lastHTTPStatusCode: Int?
            let maxRetries = 3
            let retryDelay: TimeInterval = 2.0 // 2 seconds
            
            for attempt in 1...maxRetries {
                do {
                    // Check if session is valid
                    guard await authService.isSessionValid else {
                        AppLogger.warning("SyncService: Session is invalid", category: .sync)
                        throw SyncError.notAuthenticated
                    }

                    // Refresh session to get latest token
                    AppLogger.debug("SyncService: Refreshing session...", category: .sync)
                    let refreshSuccess = await authService.refreshSession()
                    if !refreshSuccess {
                        AppLogger.warning("SyncService: Session refresh failed", category: .sync)
                        // リフレッシュ失敗でもアクセストークンが有効かもしれないので続行
                    }
                    
                    // Get access token (refreshSession()でキャッシュされた最新トークンを取得)
                    guard let accessToken = await authService.accessToken else {
                        AppLogger.warning("SyncService: Cannot get access token", category: .sync)
                        throw SyncError.notAuthenticated
                    }
                    
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
                    
                    let encoder = JSONEncoder()
                    urlRequest.httpBody = try encoder.encode(request)
                    
                    AppLogger.debug("SyncService: Sending HTTP request...", category: .sync)
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw SyncError.uploadFailed("Invalid response type")
                    }
                    
                    AppLogger.debug("SyncService: HTTP response received - Status: \(httpResponse.statusCode)", category: .sync)
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Parse error response to get detailed error message
                        var errorMessage = "Unknown error"
                        if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                           let message = errorData["message"] ?? errorData["error"] {
                            errorMessage = message
                        } else if let errorString = String(data: data, encoding: .utf8) {
                            errorMessage = errorString
                        }
                        AppLogger.error("SyncService: HTTP error - Status: \(httpResponse.statusCode), Message: \(errorMessage)", category: .sync)
                        lastHTTPStatusCode = httpResponse.statusCode
                        throw SyncError.uploadFailed("Edge Function returned a non-2xx status code: \(httpResponse.statusCode)")
                    }
                    
                    let decoder = JSONDecoder()
                    let responseData: SaveTranscriptResponse = try decoder.decode(SaveTranscriptResponse.self, from: data)
                    
                    AppLogger.info("SyncService: Web save successful - Web ID: \(responseData.id)", category: .sync)
                    
                    // Mark as saved
                    lectureStore.markAsSavedToWeb(lecture, webId: responseData.id)
                    
                    return responseData.id
                } catch {
                    lastError = error
                    let errorMessage = error.localizedDescription
                    AppLogger.error("SyncService: Web save error (attempt \(attempt)/\(maxRetries)) - \(errorMessage)", category: .sync)
                    
                    // 401エラー（認証エラー）の場合、セッションをリフレッシュして再試行
                    let isAuthError = lastHTTPStatusCode == 401 || lastHTTPStatusCode == 403
                    if isAuthError && attempt < maxRetries {
                        AppLogger.warning("SyncService: Authentication error occurred (HTTP \(lastHTTPStatusCode ?? 0)). Refreshing session and retrying...", category: .sync)
                        lastHTTPStatusCode = nil
                        await authService.refreshSession()
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }

                    // If auth error and max retries reached
                    if isAuthError {
                        AppLogger.warning("SyncService: Stopping retry due to authentication error (HTTP \(lastHTTPStatusCode ?? 0))", category: .sync)
                        break
                    }
                    
                    if let urlError = error as? URLError {
                        AppLogger.debug("SyncService: URL Error Code: \(urlError.code.rawValue), Description: \(urlError.localizedDescription)", category: .sync)

                        // ネットワークエラーの場合のみリトライ
                        if urlError.code == .networkConnectionLost || 
                           urlError.code == .timedOut ||
                           urlError.code == .notConnectedToInternet {
                            
                            if attempt < maxRetries {
                                AppLogger.debug("SyncService: Retrying in \(retryDelay) seconds...", category: .sync)
                                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                                continue
                            }
                        }
                    }

                    // その他のエラーもリトライを試みる（サーバーエラーなど）
                    if attempt < maxRetries {
                        AppLogger.debug("SyncService: Retrying in \(retryDelay) seconds...", category: .sync)
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }
                    
                    // 最大試行回数に達した場合
                    break
                }
            }
            
            // すべてのリトライが失敗した場合
            let errorMessage = lastError?.localizedDescription ?? "Unknown error"
            AppLogger.error("SyncService: Web save failed (all \(maxRetries) attempts failed)", category: .sync)
            lastSyncError = errorMessage
            throw SyncError.uploadFailed(errorMessage)
        } catch {
            let errorMessage = error.localizedDescription
            AppLogger.error("SyncService: Web save error - \(errorMessage)", category: .sync)
            if let urlError = error as? URLError {
                AppLogger.debug("SyncService: URL Error Code: \(urlError.code.rawValue), Description: \(urlError.localizedDescription)", category: .sync)
            }
            lastSyncError = errorMessage
            throw SyncError.uploadFailed(errorMessage)
        }
    }
    
    /// Retry pending uploads
    func retryPendingUploads() async {
        let pendingLectures = lectureStore.getPendingUploads()
        
        guard !pendingLectures.isEmpty else {
            AppLogger.debug("SyncService: No pending uploads", category: .sync)
            return
        }
        
        AppLogger.debug("SyncService: Retrying pending uploads - \(pendingLectures.count) items", category: .sync)
        isSyncing = true
        
        var successCount = 0
        var failureCount = 0
        
        for (index, lecture) in pendingLectures.enumerated() {
            AppLogger.debug("SyncService: [\(index + 1)/\(pendingLectures.count)] Uploading...", category: .sync)
            do {
                _ = try await saveToWeb(lecture: lecture)
                successCount += 1
            } catch {
                AppLogger.error("SyncService: Upload failed for lecture \(lecture.id): \(error)", category: .sync)
                failureCount += 1
                // Continue with next lecture even if error occurs
            }
        }
        
        isSyncing = false
        updatePendingCount()
        AppLogger.info("SyncService: Retry completed - Success: \(successCount), Failed: \(failureCount)", category: .sync)
    }
    
    /// 保留中の数を更新
    private func updatePendingCount() {
        pendingCount = lectureStore.getPendingUploads().count
    }
    
    /// Web側のタイトルを更新
    func updateTitleOnWeb(lecture: Lecture, newTitle: String) async throws {
        guard let webId = lecture.webTranscriptId else {
            AppLogger.warning("SyncService: No Web ID - Skipping title update", category: .sync)
            return
        }
        
        guard await authService.isSessionValid else {
            AppLogger.error("SyncService: Not authenticated", category: .sync)
            throw SyncError.notAuthenticated
        }

        AppLogger.debug("SyncService: Starting Web title update - Web ID: \(webId)", category: .sync)
        
        // Refresh session to get latest token
        await authService.refreshSession()
        
        guard let accessToken = await authService.accessToken else {
            AppLogger.warning("SyncService: Cannot get access token", category: .sync)
            throw SyncError.notAuthenticated
        }

        // Call Web API to update title
        let updateURL = SupabaseConfig.webBaseURL.appendingPathComponent("api/transcripts/\(webId.uuidString)/title")
        
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
            AppLogger.info("SyncService: Web title update successful", category: .sync)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            AppLogger.error("SyncService: Web title update failed - Status: \(httpResponse.statusCode), Message: \(errorMessage)", category: .sync)
            throw SyncError.uploadFailed("Failed to update title: \(errorMessage)")
        }
    }
    
    /// Get latest titles from Web and update iOS app lectures
    func syncTitlesFromWeb() async throws {
        guard await authService.isSessionValid else {
            AppLogger.warning("SyncService: Not authenticated - Skipping title sync", category: .sync)
            return
        }
        
        AppLogger.debug("SyncService: Starting title sync from Web", category: .sync)
        
        // セッションをリフレッシュして最新のトークンを取得
        await authService.refreshSession()
        
        guard let accessToken = await authService.accessToken else {
            AppLogger.warning("SyncService: Cannot get access token", category: .sync)
            throw SyncError.notAuthenticated
        }
        
        // Supabase REST APIからtranscriptsを取得
        let config = SupabaseConfig.shared
        let baseURL = config.supabaseURL.appendingPathComponent("rest/v1/transcripts")
        
        // URLにクエリパラメータを追加（apikeyはヘッダーに設定するため、クエリパラメータには含めない）
        guard var urlComponents = URLComponents(string: baseURL.absoluteString) else {
            throw SyncError.uploadFailed("Failed to create REST API URL")
        }
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
                AppLogger.debug("SyncService: Response data - \(responseString.prefix(200))...", category: .sync)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let transcripts: [WebTranscript]
            do {
                transcripts = try decoder.decode([WebTranscript].self, from: data)
                AppLogger.info("SyncService: Fetched \(transcripts.count) transcripts from Web", category: .sync)
            } catch {
                AppLogger.error("SyncService: JSON decode error - \(error.localizedDescription)", category: .sync)
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        AppLogger.debug("SyncService: Type mismatch: \(type), Context: \(context)", category: .sync)
                    case .valueNotFound(let type, let context):
                        AppLogger.debug("SyncService: Value not found: \(type), Context: \(context)", category: .sync)
                    case .keyNotFound(let key, let context):
                        AppLogger.debug("SyncService: Key not found: \(key), Context: \(context)", category: .sync)
                    case .dataCorrupted(let context):
                        AppLogger.debug("SyncService: Data corrupted: \(context)", category: .sync)
                    @unknown default:
                        AppLogger.debug("SyncService: Unknown decoding error", category: .sync)
                    }
                }
                // 空の配列を返してエラーを無視（タイトル同期はオプショナルな機能）
                AppLogger.warning("SyncService: Skipping title sync", category: .sync)
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
                        AppLogger.info("SyncService: Title updated - ID: \(transcript.id), Title: \(webTitle)", category: .sync)
                    }
                }
            }
            
            AppLogger.info("SyncService: Title sync completed - \(updatedCount) items updated", category: .sync)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            AppLogger.error("SyncService: Web title fetch failed - Status: \(httpResponse.statusCode), Message: \(errorMessage)", category: .sync)
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
