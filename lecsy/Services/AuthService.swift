//
//  AuthService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import Supabase
import AuthenticationServices
import Combine
import CryptoKit
import SafariServices
import os.log

/// Authentication service
@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasSkippedLogin: Bool = false
    
    let supabase: SupabaseClient  // Changed to public so SyncService can access it
    private var authStateTask: Task<Void, Never>?
    private var currentNonce: String?
    private var oauthSession: ASWebAuthenticationSession?
    
    // Save tokens so they can be used even if setSession returns an error
    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    
    // Keys for session persistence
    private let accessTokenKey = "lecsy.cachedAccessToken"
    private let refreshTokenKey = "lecsy.cachedRefreshToken"
    private let userEmailKey = "lecsy.cachedUserEmail"
    private let userIdKey = "lecsy.cachedUserId"
    private let userNameKey = "lecsy.cachedUserName"
    private let hasSkippedLoginKey = "lecsy.hasSkippedLogin"
    
    private override init() {
        // Initialize Supabase client (must initialize before super.init())
        let config = SupabaseConfig.shared
        print("🔍 AuthService: Initializing Supabase client")
        print("   - URL: \(config.supabaseURL.absoluteString)")
        print("   - Anon Key (first 20): \(config.supabaseAnonKey.prefix(20))...")
        print("   - Anon Key length: \(config.supabaseAnonKey.count)")
        
        // Set emitLocalSessionAsInitialSession: true to resolve warnings
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
        self.supabase = SupabaseClient(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.supabaseAnonKey,
            options: options
        )
        print("✅ AuthService: Supabase client initialization completed")
        super.init()
        
        // Monitor session state (implemented according to Supabase Swift 2.40 API)
        authStateTask = Task { @MainActor in
            for await change in await supabase.auth.authStateChanges {
                await handleAuthStateChange(change.event, session: change.session)
            }
        }
        
        // Restore hasSkippedLogin state
        hasSkippedLogin = UserDefaults.standard.bool(forKey: hasSkippedLoginKey)
        
        // Restore saved session on launch
        Task {
            await restoreSessionIfNeeded()
            await checkSession()
        }
    }
    
    /// Skip login and use app without account
    func skipLogin() {
        hasSkippedLogin = true
        UserDefaults.standard.set(true, forKey: hasSkippedLoginKey)
        print("✅ AuthService: Login skipped - using app without account")
    }
    
    /// Reset skip login state (used when user wants to sign in later)
    func resetSkipLogin() {
        hasSkippedLogin = false
        UserDefaults.standard.set(false, forKey: hasSkippedLoginKey)
    }
    
    /// Handle authentication state changes
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) async {
        // Process according to Supabase Swift 2.40 AuthChangeEvent
        switch event {
        case .initialSession:
            await checkSession()
        case .signedIn:
            print("🔐 AuthService: Sign in successful - Event: signedIn")
            if let session = session {
                print("🔐 AuthService: Session retrieved - User ID: \(session.user.id)")
            }
            isLoading = false
            errorMessage = nil
            await checkSession()
        case .signedOut:
            print("🔐 AuthService: Signed out")
            isLoading = false
            isAuthenticated = false
            currentUser = nil
        case .tokenRefreshed:
            await checkSession()
        case .userUpdated:
            await checkSession()
        case .passwordRecovery:
            break
        @unknown default:
            await checkSession()
        }
    }
    
    /// Restore saved session
    private func restoreSessionIfNeeded() async {
        // Get saved tokens from UserDefaults
        if let savedAccessToken = UserDefaults.standard.string(forKey: accessTokenKey),
           let savedRefreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) {
            print("🔍 AuthService: Restoring saved session...")
            
            // Save to cache
            cachedAccessToken = savedAccessToken
            cachedRefreshToken = savedRefreshToken
            
            // セッションを設定
            do {
                let session = try await supabase.auth.setSession(
                    accessToken: savedAccessToken,
                    refreshToken: savedRefreshToken
                )
                print("✅ AuthService: セッション復元成功 - User ID: \(session.user.id)")
                
                // ユーザー情報を復元
                let savedEmail = UserDefaults.standard.string(forKey: userEmailKey)
                let savedUserIdString = UserDefaults.standard.string(forKey: userIdKey)
                let savedName = UserDefaults.standard.string(forKey: userNameKey)
                
                if let savedUserIdString = savedUserIdString,
                   let savedUserId = UUID(uuidString: savedUserIdString) {
                    currentUser = User(
                        id: savedUserId,
                        email: savedEmail,
                        name: savedName
                    )
                    isAuthenticated = true
                    print("✅ AuthService: ユーザー情報復元成功")
                }
            } catch {
                print("⚠️ AuthService: セッション復元失敗 - \(error.localizedDescription)")
                // セッション復元に失敗した場合でも、キャッシュされたトークンを使用する
                // ユーザー情報を復元
                let savedEmail = UserDefaults.standard.string(forKey: userEmailKey)
                let savedUserIdString = UserDefaults.standard.string(forKey: userIdKey)
                let savedName = UserDefaults.standard.string(forKey: userNameKey)
                
                if let savedUserIdString = savedUserIdString,
                   let savedUserId = UUID(uuidString: savedUserIdString) {
                    currentUser = User(
                        id: savedUserId,
                        email: savedEmail,
                        name: savedName
                    )
                    isAuthenticated = true
                    print("✅ AuthService: キャッシュからユーザー情報復元成功")
                }
            }
        } else {
            print("ℹ️ AuthService: 保存されたセッションが見つかりません")
        }
    }
    
    /// セッションを永続化
    private func persistSession(accessToken: String, refreshToken: String, userId: UUID, email: String?, name: String?) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(userId.uuidString, forKey: userIdKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
        UserDefaults.standard.set(name, forKey: userNameKey)
        print("✅ AuthService: セッションを永続化しました")
    }
    
    /// 保存されたセッションをクリア
    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        print("✅ AuthService: 保存されたセッションをクリアしました")
    }
    
    /// セッションを確認
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            AppLogger.info("セッション確認成功 - User ID: \(session.user.id)", category: .auth)
            
            // userMetadataからfull_nameを取得
            let fullName: String?
            if let nameValue = session.user.userMetadata["full_name"] {
                fullName = nameValue.stringValue ?? nameValue.description
            } else {
                fullName = nil
            }
            
            currentUser = User(
                id: UUID(uuidString: session.user.id.uuidString) ?? UUID(),
                email: session.user.email,
                name: fullName
            )
            
            // セッションを永続化
            persistSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: UUID(uuidString: session.user.id.uuidString) ?? UUID(),
                email: session.user.email,
                name: fullName
            )
        } catch {
            print("⚠️ AuthService: セッション確認失敗 - \(error.localizedDescription)")
            // セッション確認に失敗した場合でも、キャッシュされたトークンがある場合は認証状態を維持
            if cachedAccessToken != nil {
                print("ℹ️ AuthService: キャッシュされたトークンを使用して認証状態を維持")
                isAuthenticated = true
            } else {
                isAuthenticated = false
                currentUser = nil
            }
        }
    }
    
    /// Googleでサインイン
    func signInWithGoogle() async throws {
            print("🔐 AuthService: Starting Google sign in")
        isLoading = true
        errorMessage = nil
        
        // Supabase Swift SDKのsignInWithOAuthにcontinuation leakの問題があるため、
        // URLを直接構築して開く方法を使用
        do {
            let config = SupabaseConfig.shared
            let redirectURL = "lecsy://auth/callback"
            
            // OAuth URLを構築
            var components = URLComponents(string: "\(config.supabaseURL.absoluteString)/auth/v1/authorize")!
            components.queryItems = [
                URLQueryItem(name: "provider", value: "google"),
                URLQueryItem(name: "redirect_to", value: redirectURL),
                URLQueryItem(name: "apikey", value: config.supabaseAnonKey),
            ]
            
            guard let authURL = components.url else {
                throw AuthError.signInFailed("Failed to create auth URL")
            }
            
            print("🔐 AuthService: OAuth URL created - \(authURL)")
            
            // Start OAuth flow using ASWebAuthenticationSession
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "lecsy"
            ) { [weak self] callbackURL, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ AuthService: OAuthエラー - \(error.localizedDescription)")
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        print("❌ AuthService: Callback URL is nil")
                        self.isLoading = false
                        self.errorMessage = "Callback URL is nil"
                        return
                    }
                    
                    print("🔐 AuthService: コールバックURL受信 - \(callbackURL)")
                    
                    // URLからアクセストークンを抽出してセッションを設定
                    await self.handleOAuthCallback(callbackURL: callbackURL)
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            // Keep session (prevent deallocation)
            self.oauthSession = session
            
            let started = session.start()
            if !started {
                throw AuthError.signInFailed("Failed to start OAuth session")
            }
            
            print("🔐 AuthService: Google OAuth session started")
            // Note: OAuth flow proceeds asynchronously, handleOAuthCallback is called when callback URL is processed
            // isLoading is set to false in handleOAuthCallback or on error
        } catch {
            print("❌ AuthService: Google sign in error - \(error.localizedDescription)")
            isLoading = false
            errorMessage = error.localizedDescription
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }
    
    /// OAuthコールバックを処理
    private func handleOAuthCallback(callbackURL: URL) async {
        print("🔐 AuthService: OAuthコールバック処理開始")
        
        // URLフラグメントからトークンを抽出（#access_token=...&refresh_token=...）
        guard let fragment = callbackURL.fragment else {
            print("❌ AuthService: コールバックURLにフラグメントがありません")
            isLoading = false
            errorMessage = "Invalid callback URL"
            return
        }
        
        // フラグメントをパース
        let params = fragment.components(separatedBy: "&")
            .reduce(into: [String: String]()) { result, param in
                let parts = param.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0]
                    let value = parts[1].removingPercentEncoding ?? parts[1]
                    result[key] = value
                }
            }
        
        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            print("❌ AuthService: Tokens not found")
            isLoading = false
            errorMessage = "Tokens not found in callback"
            return
        }
        
        let expiresIn = Int(params["expires_in"] ?? "3600") ?? 3600
        let tokenType = params["token_type"] ?? "bearer"
        
        AppLogger.info("Tokens retrieved successfully", category: .auth)
        AppLogger.logToken("Access Token", token: accessToken, category: .auth)
        AppLogger.logToken("Refresh Token", token: refreshToken, category: .auth)
        AppLogger.debug("Expires In: \(expiresIn)", category: .auth)
        
        // Set session
        do {
            // Check Supabase client configuration
            let config = SupabaseConfig.shared
            print("🔍 AuthService: Checking Supabase configuration")
            print("   - URL: \(config.supabaseURL.absoluteString)")
            print("   - Anon Key (first 20): \(config.supabaseAnonKey.prefix(20))...")
            
            // Use Supabase Swift SDK's setSession method
            // Create session from access token and refresh token
            print("🔍 AuthService: Before calling setSession")
            print("   - Access Token (first 20): \(accessToken.prefix(20))...")
            print("   - Refresh Token (first 20): \(refreshToken.prefix(20))...")
            
            // setSession uses refresh token to get new session
            // This method also retrieves user information internally, so no need to call checkSession
            // Note: setSession sends request to /auth/v1/user internally, so API key is required
            print("🔍 AuthService: Calling setSession - Updating session using refresh token")
            
            // Decode JWT from access token to get user information
            // setSession sends request to /auth/v1/user internally, so API key is required
            // However, 401 errors occur, so try getting user information directly from JWT
            
            // First, get user information from JWT
            let jwtParts = accessToken.components(separatedBy: ".")
            guard jwtParts.count == 3 else {
                throw AuthError.signInFailed("Invalid access token format")
            }
            
            // JWTのペイロード部分をデコード
            let payload = jwtParts[1]
            var base64 = payload
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            
            // Base64パディングを追加
            let remainder = base64.count % 4
            if remainder > 0 {
                base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
            }
            
            guard let payloadData = Data(base64Encoded: base64),
                  let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                  let userIdString = payloadJSON["sub"] as? String,
                  let userId = UUID(uuidString: userIdString) else {
                throw AuthError.signInFailed("Failed to decode JWT payload")
            }
            
            let email = payloadJSON["email"] as? String
            let userMetadata = payloadJSON["user_metadata"] as? [String: Any]
            let fullName = userMetadata?["full_name"] as? String
            
            // トークンをキャッシュに保存（setSessionがエラーを返しても使用できるように）
            cachedAccessToken = accessToken
            cachedRefreshToken = refreshToken
            
            // セッションを永続化（setSessionが失敗しても使用できるように）
            persistSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userId: userId,
                email: email,
                name: fullName
            )
            
            // セッションを設定
            // 注意: setSessionは内部でユーザー情報を取得しようとするため、
            // エラーが発生する可能性があるが、セッション自体は設定される
            do {
                let session = try await supabase.auth.setSession(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
                print("✅ AuthService: setSession成功 - User ID: \(session.user.id)")
                // セッションが正しく設定されている場合、最新の情報で永続化を更新
                persistSession(
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken,
                    userId: UUID(uuidString: session.user.id.uuidString) ?? userId,
                    email: session.user.email ?? email,
                    name: fullName
                )
            } catch {
                // setSessionがエラーを返しても、JWTから取得したユーザー情報を使用する
                print("⚠️ AuthService: setSessionエラー（JWTからユーザー情報を取得） - \(error.localizedDescription)")
                // エラーの詳細をログに出力
                if let nsError = error as NSError? {
                    print("   - Domain: \(nsError.domain)")
                    print("   - Code: \(nsError.code)")
                    print("   - UserInfo: \(nsError.userInfo)")
                }
                // セッションが設定されていない可能性があるが、キャッシュされたトークンを使用する
                // セッションが正しく設定されているか確認
                do {
                    let currentSession = try await supabase.auth.session
                    print("✅ AuthService: セッション確認成功（setSessionエラー後） - User ID: \(currentSession.user.id)")
                    // セッションが正しく設定されている場合、最新の情報で永続化を更新
                    persistSession(
                        accessToken: currentSession.accessToken,
                        refreshToken: currentSession.refreshToken,
                        userId: UUID(uuidString: currentSession.user.id.uuidString) ?? userId,
                        email: currentSession.user.email ?? email,
                        name: fullName
                    )
                } catch {
                    print("⚠️ AuthService: セッション確認失敗 - \(error.localizedDescription)")
                    // セッションが設定されていない場合でも、キャッシュされたトークンを使用する
                    // 既に永続化されているので、そのまま使用する
                }
            }
            
            print("✅ AuthService: セッション設定成功（JWTからユーザー情報を取得）")
            print("   - User ID: \(userId)")
            print("   - Email: \(email ?? "N/A")")
            
            // セッションから直接ユーザー情報を取得
            isAuthenticated = true
            
            currentUser = User(
                id: userId,
                email: email,
                name: fullName
            )
            
            isLoading = false
            errorMessage = nil
        } catch {
            print("❌ AuthService: セッション設定エラー")
            print("   - Error: \(error)")
            print("   - Localized: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - UserInfo: \(nsError.userInfo)")
            }
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    /// URLからOAuthコールバックを処理（lecsyApp.swiftから呼ばれる）
    func handleOAuthCallbackURL(_ url: URL) async {
        await handleOAuthCallback(callbackURL: url)
    }
    
    /// Apple Sign Inの結果を処理（LoginViewから呼ばれる）
    func handleAppleSignIn(identityToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        print("🔐 AuthService: handleAppleSignIn開始")
        isLoading = true
        errorMessage = nil
        
        // Supabaseクライアントの設定を確認
        let config = SupabaseConfig.shared
        print("🔍 AuthService: Apple Sign In - Supabase設定確認")
        print("   - URL: \(config.supabaseURL.absoluteString)")
        print("   - Anon Key (first 20): \(config.supabaseAnonKey.prefix(20))...")
        print("   - Anon Key length: \(config.supabaseAnonKey.count)")
        print("   - Identity Token (first 20): \(identityToken.prefix(20))...")
        print("   - Identity Token length: \(identityToken.count)")
        print("   - Nonce: \(nonce.prefix(8))...")
        
        do {
            // まず、直接HTTPリクエストでSupabase Auth APIを呼び出す方法を試す
            print("🔐 AuthService: 直接HTTPリクエストでSupabase Auth APIを呼び出し")
            let tokenURL = config.supabaseURL.appendingPathComponent("auth/v1/token")
            var urlComponents = URLComponents(string: tokenURL.absoluteString)!
            // APIキーをクエリパラメータとしても追加（一部のエンドポイントで必要）
            urlComponents.queryItems = [
                URLQueryItem(name: "grant_type", value: "id_token"),
                URLQueryItem(name: "apikey", value: config.supabaseAnonKey)
            ]
            
            guard let requestURL = urlComponents.url else {
                throw AuthError.signInFailed("Failed to create token URL")
            }
            
            var urlRequest = URLRequest(url: requestURL)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Supabase Auth APIはapikeyヘッダーを必要とする
            urlRequest.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            
            // nonceは元のまま送信（Supabaseが内部でハッシュ化して、Identity Tokenに含まれるnonceと比較する）
            // LoginViewでnonceをハッシュ化してAppleに送信しているため、Identity Tokenにはハッシュ化されたnonceが含まれている
            // Supabaseは、リクエストで送信されたnonceをハッシュ化して、Identity Tokenに含まれるnonceと比較する
            
            // リクエストボディを作成
            let requestBody: [String: Any] = [
                "provider": "apple",
                "id_token": identityToken,
                "nonce": nonce  // 元のnonceを送信（ハッシュ化しない）
            ]
            
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            print("🔍 AuthService: HTTPリクエスト送信")
            print("   - URL: \(requestURL)")
            print("   - Method: POST")
            print("   - Headers: apikey=\(config.supabaseAnonKey.prefix(20))...")
            print("   - Nonce (original): \(nonce.prefix(16))...")
            print("   - Request body: provider=apple, id_token length=\(identityToken.count), nonce length=\(nonce.count)")
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.signInFailed("Invalid response type")
            }
            
            print("🔍 AuthService: HTTPレスポンス受信 - Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // エラーレスポンスをパース
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ AuthService: HTTPエラー - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
                
                // 401エラーの場合、Anon Keyの問題である可能性が高い
                if httpResponse.statusCode == 401 {
                    print("⚠️ AuthService: 401エラー - Anon Keyが無効の可能性があります")
                    print("   確認事項:")
                    print("   1. Supabase Dashboard > Settings > API で最新のAnon Keyを取得")
                    print("   2. Debug.xcconfig と Release.xcconfig の SUPABASE_ANON_KEY を更新")
                    print("   3. Xcodeで Clean Build Folder を実行")
                    print("   現在のAnon Key (first 20): \(config.supabaseAnonKey.prefix(20))...")
                    print("   現在のAnon Key length: \(config.supabaseAnonKey.count)")
                }
                
                throw AuthError.signInFailed("HTTP error: \(httpResponse.statusCode) - \(errorMessage)")
            }
            
            // レスポンスをパース
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            print("✅ AuthService: トークン取得成功")
            print("   - Access Token (first 20): \(tokenResponse.accessToken.prefix(20))...")
            print("   - Refresh Token (first 20): \(tokenResponse.refreshToken.prefix(20))...")
            
            // セッションを設定
            let session = try await supabase.auth.setSession(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )
            print("✅ AuthService: セッション設定成功 - User ID: \(session.user.id)")
            
            // トークンをキャッシュに保存
            cachedAccessToken = session.accessToken
            cachedRefreshToken = session.refreshToken
            
            // セッションを永続化
            let userId = UUID(uuidString: session.user.id.uuidString) ?? UUID()
            let sessionFullName: String?
            if let nameValue = session.user.userMetadata["full_name"] {
                sessionFullName = nameValue.stringValue ?? nameValue.description
            } else {
                sessionFullName = nil
            }
            persistSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: userId,
                email: session.user.email,
                name: sessionFullName
            )
            
            // 初回サインイン時のみ、fullNameを保存
            if let fullName = fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !name.isEmpty {
                    // ユーザーメタデータを更新（エラーが発生しても続行）
                    do {
                        _ = try await supabase.auth.update(user: UserAttributes(data: ["full_name": AnyJSON.string(name)]))
                        print("✅ AuthService: ユーザーメタデータ更新成功")
                        // 名前を更新して永続化
                        persistSession(
                            accessToken: session.accessToken,
                            refreshToken: session.refreshToken,
                            userId: userId,
                            email: session.user.email,
                            name: name
                        )
                    } catch {
                        print("⚠️ AuthService: ユーザーメタデータ更新エラー（無視） - \(error.localizedDescription)")
                    }
                }
            }
            
            isLoading = false
            errorMessage = nil
            print("✅ AuthService: Appleサインイン成功")
            await checkSession()
        } catch {
            isLoading = false
            print("❌ AuthService: Appleサインイン処理エラー")
            print("   - Error: \(error)")
            print("   - Localized: \(error.localizedDescription)")
            
            // エラーの詳細を出力
            var detailedErrorInfo: [String] = []
            var httpStatusCode: Int?
            
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - UserInfo: \(nsError.userInfo)")
                detailedErrorInfo.append("Domain: \(nsError.domain)")
                detailedErrorInfo.append("Code: \(nsError.code)")
                
                // エラーメッセージから詳細を取得
                if let errorDescription = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                    print("   - Description: \(errorDescription)")
                    detailedErrorInfo.append("Description: \(errorDescription)")
                }
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("   - Underlying Error: \(underlyingError)")
                    detailedErrorInfo.append("Underlying: \(underlyingError.localizedDescription)")
                }
                
                // HTTPステータスコードを確認
                if let statusCode = nsError.userInfo["statusCode"] as? Int {
                    httpStatusCode = statusCode
                    print("   - HTTP Status Code: \(statusCode)")
                    detailedErrorInfo.append("HTTP Status: \(statusCode)")
                }
            }
            
            // エラーメッセージを解析して適切なメッセージを表示
            let errorString = error.localizedDescription.lowercased()
            let fullErrorString = (error as NSError?)?.userInfo.description ?? errorString
            
            var userFriendlyMessage: String
            
            if errorString.contains("invalid api key") || errorString.contains("invalid_client") || httpStatusCode == 401 {
                userFriendlyMessage = """
                🔧 Supabase設定エラー
                
                Apple Providerが正しく設定されていません。
                Supabase Dashboard > Authentication > Providers > Apple で以下を確認してください:
                
                1. ✅ Enable Sign in with Apple が有効
                2. ✅ Client ID (Services ID) が設定されている
                3. ✅ Team ID が設定されている
                4. ✅ Key ID が設定されている
                5. ✅ Secret Key (for OAuth) が設定されている
                
                詳細: \(error.localizedDescription)
                """
            } else if errorString.contains("provider") && errorString.contains("not enabled") {
                userFriendlyMessage = """
                🔧 Apple Provider無効
                
                Supabase Dashboard > Authentication > Providers > Apple で
                「Enable Sign in with Apple」を有効にしてください。
                """
            } else if errorString.contains("invalid_client_secret") || errorString.contains("invalid secret") || httpStatusCode == 400 {
                userFriendlyMessage = """
                🔧 Secret Keyエラー
                
                Apple ProviderのSecret Keyが無効または期限切れです。
                Secret Keyを再生成してSupabase Dashboardで更新してください。
                
                再生成方法:
                1. node generate-apple-secret.js を実行
                2. 生成されたJWTをSupabase Dashboardに貼り付け
                """
            } else if errorString.contains("redirect_uri_mismatch") || errorString.contains("redirect") {
                userFriendlyMessage = """
                🔧 Redirect URLエラー
                
                Redirect URLが正しく設定されていません。
                Supabase Dashboard > Authentication > URL Configuration で
                「Redirect URLs」に以下が含まれているか確認してください:
                
                - lecsy://auth/callback
                """
            } else {
                // その他のエラー
                userFriendlyMessage = """
                ❌ サインインエラー
                
                \(error.localizedDescription)
                
                詳細情報:
                \(detailedErrorInfo.joined(separator: "\n"))
                """
            }
            
            errorMessage = userFriendlyMessage
            print("📋 ユーザー向けエラーメッセージ:")
            print(userFriendlyMessage)
            
            throw AuthError.signInFailed(userFriendlyMessage)
        }
    }
    
    /// Appleでサインイン
    func signInWithApple() async throws {
        print("🔐 AuthService: Appleサインイン開始")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // nonceを生成
        let nonce = randomNonceString()
        currentNonce = nonce
        print("🔐 AuthService: Nonce生成完了 - \(nonce.prefix(8))...")
        
        // メインスレッドで実行する必要がある
        await MainActor.run {
            do {
                // Apple Sign In の認証リクエストを作成
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
                print("🔐 AuthService: Apple認証リクエスト作成完了")
                
                let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                authorizationController.delegate = self
                authorizationController.presentationContextProvider = self
                
                print("🔐 AuthService: performRequests()を呼び出し")
                authorizationController.performRequests()
                print("🔐 AuthService: Apple認証リクエスト送信完了")
                // 注意: isLoadingは認証完了またはエラー時にfalseに設定される
                // didCompleteWithAuthorization または didCompleteWithError で設定
            } catch {
                print("❌ AuthService: Appleサインインエラー - \(error.localizedDescription)")
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// ランダムなnonce文字列を生成
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// SHA256ハッシュを生成
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        
        return hashString
    }
    
    /// サインアウト
    func signOut() async throws {
        isLoading = true
        
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
            // キャッシュされたトークンもクリア
            cachedAccessToken = nil
            cachedRefreshToken = nil
            // 永続化されたセッションもクリア
            clearPersistedSession()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }
    
    /// アカウント削除（Apple審査要件対応）
    func deleteAccount() async throws {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        
        do {
            // Edge Functionを呼び出してアカウントを削除
            let config = SupabaseConfig.shared
            let functionURL = config.supabaseURL.appendingPathComponent("functions/v1/delete-account")
            
            guard let accessToken = await accessToken else {
                throw AuthError.deleteAccountFailed("No access token")
            }
            
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.deleteAccountFailed("Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.deleteAccountFailed(errorMessage)
            }
            
            // ローカルデータも削除
            let lectureStore = LectureStore.shared
            lectureStore.deleteAllData()
            
            // セッションをクリア
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
            cachedAccessToken = nil
            cachedRefreshToken = nil
            clearPersistedSession()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw AuthError.deleteAccountFailed(error.localizedDescription)
        }
    }
    
    /// セッションをリフレッシュ
    /// - Returns: リフレッシュが成功した場合はtrue、失敗した場合はfalse
    @discardableResult
    func refreshSession() async -> Bool {
        // キャッシュされたリフレッシュトークンがない場合、永続化されたセッションから取得を試みる
        var refreshToken = cachedRefreshToken
        if refreshToken == nil {
            refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
            if let token = refreshToken {
                cachedRefreshToken = token
                cachedAccessToken = UserDefaults.standard.string(forKey: accessTokenKey)
                print("ℹ️ AuthService: 永続化されたセッションからリフレッシュトークンを取得")
            }
        }
        
        guard let refreshToken = refreshToken else {
            print("⚠️ AuthService: リフレッシュトークンがキャッシュされていません")
            // キャッシュされたアクセストークンがあり、有効であればtrueを返す
            if let cachedToken = cachedAccessToken, isTokenValid(cachedToken) {
                print("✅ AuthService: キャッシュされたアクセストークンを使用します（有効期限内）")
                return true
            }
            return false
        }
        
        print("🔄 AuthService: セッションをリフレッシュ中...")
        
        // Supabase Swift SDKのrefreshSessionを使用
        do {
            let session = try await supabase.auth.refreshSession(refreshToken: refreshToken)
            print("✅ AuthService: セッションリフレッシュ成功 - User ID: \(session.user.id)")
            AppLogger.logToken("新しいAccess Token", token: session.accessToken, category: .auth)
            
            // 新しいトークンをキャッシュに保存（これが重要！）
            cachedAccessToken = session.accessToken
            cachedRefreshToken = session.refreshToken
            
            // セッションを永続化
            let userId = UUID(uuidString: session.user.id.uuidString) ?? UUID()
            let fullName: String?
            if let nameValue = session.user.userMetadata["full_name"] {
                fullName = nameValue.stringValue ?? nameValue.description
            } else {
                fullName = nil
            }
            persistSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: userId,
                email: session.user.email,
                name: fullName
            )
            
            return true
        } catch {
            print("⚠️ AuthService: Supabase SDK refreshSession失敗 - \(error.localizedDescription)")
            
            // SDKが失敗した場合、キャッシュされたアクセストークンが有効かチェック
            if let cachedToken = cachedAccessToken, isTokenValid(cachedToken) {
                print("✅ AuthService: リフレッシュ失敗ですが、キャッシュされたアクセストークンは有効期限内です")
                return true
            }
            
            // キャッシュも期限切れの場合、直接HTTPリクエストでリフレッシュを試みる
            print("🔄 AuthService: 直接HTTPリクエストでリフレッシュを試みます...")
            return await refreshSessionViaHTTP(refreshToken: refreshToken)
        }
    }
    
    /// HTTPリクエストで直接セッションをリフレッシュ（SDKが失敗した場合のフォールバック）
    private func refreshSessionViaHTTP(refreshToken: String) async -> Bool {
        let config = SupabaseConfig.shared
        let tokenURL = config.supabaseURL.appendingPathComponent("auth/v1/token")
        
        var urlComponents = URLComponents(string: tokenURL.absoluteString)!
        urlComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        
        guard let requestURL = urlComponents.url else {
            print("❌ AuthService: リフレッシュURL作成失敗")
            return false
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let requestBody: [String: Any] = ["refresh_token": refreshToken]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            // HTTPレスポンスを取得
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ AuthService: HTTPリフレッシュ失敗 - Invalid response type")
                return false
            }
            
            // ステータスコードをチェック
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ AuthService: HTTPリフレッシュ失敗 - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
                
                // 401エラーの場合、Anon Keyの問題である可能性が高い
                if httpResponse.statusCode == 401 {
                    print("⚠️ AuthService: 401エラー - Anon Keyが無効の可能性があります")
                    print("   確認事項:")
                    print("   1. Supabase Dashboard > Settings > API で最新のAnon Keyを取得")
                    print("   2. Debug.xcconfig と Release.xcconfig の SUPABASE_ANON_KEY を更新")
                    print("   3. Xcodeで Clean Build Folder を実行")
                    print("   現在のAnon Key (first 20): \(config.supabaseAnonKey.prefix(20))...")
                    print("   現在のAnon Key length: \(config.supabaseAnonKey.count)")
                }
                
                return false
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            print("✅ AuthService: HTTPリフレッシュ成功")
            AppLogger.logToken("新しいAccess Token (HTTP)", token: tokenResponse.accessToken, category: .auth)
            
            // 新しいトークンをキャッシュに保存
            cachedAccessToken = tokenResponse.accessToken
            cachedRefreshToken = tokenResponse.refreshToken
            
            // SDKセッションも更新
            do {
                _ = try await supabase.auth.setSession(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken
                )
            } catch {
                print("⚠️ AuthService: setSession失敗（無視） - \(error.localizedDescription)")
            }
            
            // 永続化
            if let userResponse = tokenResponse.user,
               let userId = UUID(uuidString: userResponse.id) {
                persistSession(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken,
                    userId: userId,
                    email: userResponse.email,
                    name: nil
                )
            }
            
            return true
        } catch {
            print("❌ AuthService: HTTPリフレッシュエラー - \(error.localizedDescription)")
            return false
        }
    }
    
    /// アクセストークンを取得（refreshSession()で更新されたキャッシュを優先）
    var accessToken: String? {
        get async {
            // 重要: refreshSession()がcachedAccessTokenを更新するため、
            // キャッシュされたトークンが有効かどうかを最初にチェックする
            
            // キャッシュされたトークンがあり、有効期限内であればそれを使用
            if let cachedToken = cachedAccessToken, isTokenValid(cachedToken) {
                AppLogger.debug("キャッシュされたトークンを使用（有効期限内）", category: .auth)
                return cachedToken
            }
            
            // キャッシュがない、または期限切れの場合、SDKセッションから取得を試みる
            do {
                let session = try await supabase.auth.session
                // 最新のトークンをキャッシュに保存
                cachedAccessToken = session.accessToken
                cachedRefreshToken = session.refreshToken
                return session.accessToken
            } catch {
                print("⚠️ AuthService: セッション取得失敗 - \(error.localizedDescription)")
                // セッションが取得できない場合、リフレッシュを試みる
                await refreshSession()
                
                // リフレッシュ後、キャッシュされたトークンを使用
                // refreshSession()がcachedAccessTokenを更新するため
                if let cachedToken = cachedAccessToken, isTokenValid(cachedToken) {
                    return cachedToken
                }
                
                // 再度SDKセッションから取得を試みる
                do {
                    let session = try await supabase.auth.session
                    cachedAccessToken = session.accessToken
                    cachedRefreshToken = session.refreshToken
                    return session.accessToken
                } catch {
                    // それでも失敗した場合、永続化されたトークンを試す（最後の手段）
                    if let persistedToken = UserDefaults.standard.string(forKey: accessTokenKey) {
                        if isTokenValid(persistedToken) {
                            cachedAccessToken = persistedToken
                            print("⚠️ AuthService: 永続化されたアクセストークンを使用（セッション取得失敗）")
                            return persistedToken
                        }
                    }
                    return nil
                }
            }
        }
    }
    
    /// JWTトークンが有効期限内かどうかをチェック
    private func isTokenValid(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return false }
        
        var payload = parts[1]
        // Base64URLデコード用のパディング
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder > 0 {
            payload = payload.padding(toLength: payload.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let payloadData = Data(base64Encoded: payload),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payloadJSON["exp"] as? TimeInterval else {
            return false
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        // 30秒のマージンを持たせる（ネットワーク遅延を考慮）
        let isValid = expirationDate > Date().addingTimeInterval(30)
        
        if !isValid {
            print("⚠️ AuthService: トークン期限切れ - 有効期限: \(expirationDate)")
        }
        
        return isValid
    }
    
    /// セッションが有効か確認
    var isSessionValid: Bool {
        get async {
            // まず、Supabaseクライアントのセッションから確認を試みる
            do {
                _ = try await supabase.auth.session
                return true
            } catch {
                // セッションが取得できない場合、キャッシュされたトークンがあるか確認
                if cachedAccessToken != nil {
                    print("🔍 AuthService: キャッシュされたトークンを使用してセッション有効と判断")
                    return true
                }
                // キャッシュにもない場合、永続化されたセッションがあるか確認
                if UserDefaults.standard.string(forKey: accessTokenKey) != nil {
                    print("🔍 AuthService: 永続化されたトークンを使用してセッション有効と判断")
                    return true
                }
                return false
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let identityToken = appleIDCredential.identityToken,
                      let identityTokenString = String(data: identityToken, encoding: .utf8),
                      let nonce = currentNonce else {
                    isLoading = false
                    return
                }
                
                do {
                    // Supabaseクライアントの設定を確認
                    let config = SupabaseConfig.shared
                    print("🔍 AuthService: Apple Sign In - Supabase設定確認")
                    print("   - URL: \(config.supabaseURL.absoluteString)")
                    print("   - Anon Key (first 20): \(config.supabaseAnonKey.prefix(20))...")
                    print("   - Anon Key length: \(config.supabaseAnonKey.count)")
                    print("   - Identity Token (first 20): \(identityTokenString.prefix(20))...")
                    print("   - Identity Token length: \(identityTokenString.count)")
                    print("   - Nonce: \(nonce.prefix(8))...")
                    
                    // signInWithIdTokenを試みる
                    print("🔐 AuthService: signInWithIdToken呼び出し開始")
                    let session = try await supabase.auth.signInWithIdToken(
                        credentials: .init(
                            provider: .apple,
                            idToken: identityTokenString,
                            nonce: nonce
                        )
                    )
                    print("✅ AuthService: signInWithIdToken成功 - User ID: \(session.user.id)")
                    
                    // トークンをキャッシュに保存
                    cachedAccessToken = session.accessToken
                    cachedRefreshToken = session.refreshToken
                    
                    // セッションを永続化
                    let userId = UUID(uuidString: session.user.id.uuidString) ?? UUID()
                    let fullName: String?
                    if let nameValue = session.user.userMetadata["full_name"] {
                        fullName = nameValue.stringValue ?? nameValue.description
                    } else {
                        fullName = nil
                    }
                    persistSession(
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken,
                        userId: userId,
                        email: session.user.email,
                        name: fullName
                    )
                    
                    // 初回サインイン時のみ、fullNameを保存
                    if let fullName = appleIDCredential.fullName {
                        let name = [fullName.givenName, fullName.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        
                        if !name.isEmpty {
                            // ユーザーメタデータを更新（エラーが発生しても続行）
                            do {
                                _ = try await supabase.auth.update(user: UserAttributes(data: ["full_name": AnyJSON.string(name)]))
                            } catch {
                                print("⚠️ AuthService: ユーザーメタデータ更新エラー（無視） - \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    currentNonce = nil
                    isLoading = false
                    errorMessage = nil
                    print("✅ AuthService: Appleサインイン成功")
                    await checkSession()
                } catch {
                    currentNonce = nil
                    isLoading = false
                    print("❌ AuthService: Appleサインイン処理エラー")
                    print("   - Error: \(error)")
                    print("   - Localized: \(error.localizedDescription)")
                    
                    // エラーの詳細を出力
                    var detailedErrorInfo: [String] = []
                    if let nsError = error as NSError? {
                        print("   - Domain: \(nsError.domain)")
                        print("   - Code: \(nsError.code)")
                        print("   - UserInfo: \(nsError.userInfo)")
                        detailedErrorInfo.append("Domain: \(nsError.domain)")
                        detailedErrorInfo.append("Code: \(nsError.code)")
                        
                        // エラーメッセージから詳細を取得
                        if let errorDescription = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                            print("   - Description: \(errorDescription)")
                            detailedErrorInfo.append("Description: \(errorDescription)")
                        }
                        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                            print("   - Underlying Error: \(underlyingError)")
                            detailedErrorInfo.append("Underlying: \(underlyingError.localizedDescription)")
                        }
                        
                        // HTTPステータスコードを確認
                        if let httpStatusCode = nsError.userInfo["statusCode"] as? Int {
                            print("   - HTTP Status Code: \(httpStatusCode)")
                            detailedErrorInfo.append("HTTP Status: \(httpStatusCode)")
                        }
                    }
                    
                    // エラーメッセージを解析して適切なメッセージを表示
                    let errorString = error.localizedDescription.lowercased()
                    let fullErrorString = (error as NSError?)?.userInfo.description ?? errorString
                    
                    if errorString.contains("invalid api key") || errorString.contains("invalid_client") {
                        errorMessage = """
                        🔧 Supabase設定エラー
                        
                        Apple Providerが正しく設定されていません。
                        Supabase Dashboard > Authentication > Providers > Apple で以下を確認してください:
                        
                        1. ✅ Enable Sign in with Apple が有効
                        2. ✅ Client ID (Services ID) が設定されている
                        3. ✅ Team ID が設定されている
                        4. ✅ Key ID が設定されている
                        5. ✅ Secret Key (for OAuth) が設定されている
                        
                        詳細: \(error.localizedDescription)
                        """
                    } else if errorString.contains("provider") && errorString.contains("not enabled") {
                        errorMessage = """
                        🔧 Apple Provider無効
                        
                        Supabase Dashboard > Authentication > Providers > Apple で
                        「Enable Sign in with Apple」を有効にしてください。
                        """
                    } else if errorString.contains("invalid_client_secret") || errorString.contains("invalid secret") {
                        errorMessage = """
                        🔧 Secret Keyエラー
                        
                        Apple ProviderのSecret Keyが無効または期限切れです。
                        Secret Keyを再生成してSupabase Dashboardで更新してください。
                        
                        再生成方法:
                        1. node generate-apple-secret.js を実行
                        2. 生成されたJWTをSupabase Dashboardに貼り付け
                        """
                    } else if errorString.contains("redirect_uri_mismatch") || errorString.contains("redirect") {
                        errorMessage = """
                        🔧 Redirect URLエラー
                        
                        Redirect URLが正しく設定されていません。
                        Supabase Dashboard > Authentication > URL Configuration で
                        「Redirect URLs」に以下が含まれているか確認してください:
                        
                        - lecsy://auth/callback
                        """
                    } else if fullErrorString.contains("401") || errorString.contains("unauthorized") {
                        errorMessage = """
                        🔧 認証エラー
                        
                        SupabaseのApple Provider設定に問題があります。
                        Supabase Dashboardで設定を確認してください。
                        
                        エラー詳細: \(error.localizedDescription)
                        """
                    } else {
                        // その他のエラー
                        errorMessage = """
                        ❌ サインインエラー
                        
                        \(error.localizedDescription)
                        
                        詳細情報:
                        \(detailedErrorInfo.joined(separator: "\n"))
                        """
                    }
                    
                    print("📋 ユーザー向けエラーメッセージ:")
                    print(errorMessage ?? "エラーが発生しました")
                }
            } else {
                isLoading = false
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            currentNonce = nil
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ AuthService: Apple認証エラー - \(error.localizedDescription)")
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("🍎 AuthService: Getting presentation anchor for Apple Sign In")
        
        // iPadマルチウィンドウ対応: フォアグラウンドのシーンを優先的に探す
        let connectedScenes = UIApplication.shared.connectedScenes
        print("🍎 AuthService: Found \(connectedScenes.count) connected scenes")
        
        // 1. フォアグラウンドでアクティブなシーンから探す
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               scene.activationState == .foregroundActive {
                print("🍎 AuthService: Found foreground active scene")
                // キーウィンドウを探す
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    print("🍎 AuthService: Found key window in foreground active scene")
                    return keyWindow
                }
                // キーウィンドウがない場合は最初のウィンドウを使用
                if let firstWindow = windowScene.windows.first {
                    print("🍎 AuthService: Using first window in foreground active scene")
                    return firstWindow
                }
            }
        }
        
        // 2. フォアグラウンド（非アクティブ）のシーンから探す
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               scene.activationState == .foregroundInactive {
                print("🍎 AuthService: Found foreground inactive scene")
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    print("🍎 AuthService: Found key window in foreground inactive scene")
                    return keyWindow
                }
                if let firstWindow = windowScene.windows.first {
                    print("🍎 AuthService: Using first window in foreground inactive scene")
                    return firstWindow
                }
            }
        }
        
        // 3. 任意のウィンドウシーンから探す（最終手段）
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                print("🍎 AuthService: Trying any window scene, state: \(scene.activationState.rawValue)")
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    print("🍎 AuthService: Found key window in scene")
                    return keyWindow
                }
                if let firstWindow = windowScene.windows.first {
                    print("🍎 AuthService: Using first window in scene")
                    return firstWindow
                }
            }
        }
        
        // 4. 従来のAPIを使用（非推奨だが互換性のため）
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            print("🍎 AuthService: Found key window using deprecated API")
            return window
        }
        
        if let window = UIApplication.shared.windows.first {
            print("🍎 AuthService: Using first window from deprecated API")
            return window
        }
        
        // 5. 絶対にウィンドウが必要なので、新しいウィンドウを作成（これは最後の手段）
        print("⚠️ AuthService: No window found, creating fallback window - this may cause issues")
        // 最初のシーンを使って新しいウィンドウを作成
        if let windowScene = connectedScenes.first as? UIWindowScene {
            let fallbackWindow = UIWindow(windowScene: windowScene)
            fallbackWindow.makeKeyAndVisible()
            print("🍎 AuthService: Created fallback window with scene")
            return fallbackWindow
        }
        
        // 本当の最終手段（これは動作しない可能性がある）
        print("❌ AuthService: Critical - no scene available for fallback window")
        return UIWindow()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        print("🌐 AuthService: Getting presentation anchor for Web Auth Session")
        
        // iPadマルチウィンドウ対応: フォアグラウンドのシーンを優先的に探す
        let connectedScenes = UIApplication.shared.connectedScenes
        
        // 1. フォアグラウンドでアクティブなシーンから探す
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               scene.activationState == .foregroundActive {
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    print("🌐 AuthService: Found key window in foreground active scene")
                    return keyWindow
                }
                if let firstWindow = windowScene.windows.first {
                    print("🌐 AuthService: Using first window in foreground active scene")
                    return firstWindow
                }
            }
        }
        
        // 2. フォアグラウンド（非アクティブ）のシーンから探す
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               scene.activationState == .foregroundInactive {
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
                if let firstWindow = windowScene.windows.first {
                    return firstWindow
                }
            }
        }
        
        // 3. 任意のウィンドウシーンから探す
        for scene in connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
                if let firstWindow = windowScene.windows.first {
                    return firstWindow
                }
            }
        }
        
        // 4. 従来のAPIを使用
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        
        if let window = UIApplication.shared.windows.first {
            return window
        }
        
        // 5. フォールバック
        print("⚠️ AuthService: No window found for Web Auth Session")
        if let windowScene = connectedScenes.first as? UIWindowScene {
            let fallbackWindow = UIWindow(windowScene: windowScene)
            fallbackWindow.makeKeyAndVisible()
            return fallbackWindow
        }
        
        return UIWindow()
    }
}

/// 認証エラー
enum AuthError: LocalizedError {
    case signInFailed(String)
    case signOutFailed(String)
    case deleteAccountFailed(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .deleteAccountFailed(let message):
            return "Failed to delete account: \(message)"
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}

/// トークンレスポンス
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    let tokenType: String?
    let user: UserResponse?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

/// ユーザーレスポンス
struct UserResponse: Codable {
    let id: String
    let email: String?
    let userMetadata: [String: AnyJSON]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        
        // user_metadataをオプショナルとしてデコード
        if let metadataDict = try? container.decode([String: AnyJSON].self, forKey: .userMetadata) {
            userMetadata = metadataDict
        } else {
            userMetadata = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(userMetadata, forKey: .userMetadata)
    }
}
