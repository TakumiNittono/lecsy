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

/// 認証サービス
@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let supabase: SupabaseClient  // SyncServiceからもアクセスできるようにpublicに変更
    private var authStateTask: Task<Void, Never>?
    private var currentNonce: String?
    private var oauthSession: ASWebAuthenticationSession?
    
    private override init() {
        // Supabaseクライアント初期化（super.init()の前に初期化が必要）
        let config = SupabaseConfig.shared
        // emitLocalSessionAsInitialSession: true を設定して警告を解消
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
        super.init()
        
        // セッション状態を監視（Supabase Swift 2.40のAPIに合わせて実装）
        authStateTask = Task { @MainActor in
            for await change in await supabase.auth.authStateChanges {
                await handleAuthStateChange(change.event, session: change.session)
            }
        }
        
        // 起動時にセッションを確認
        Task {
            await checkSession()
        }
    }
    
    /// 認証状態の変更を処理
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) async {
        // Supabase Swift 2.40のAuthChangeEventに合わせて処理
        switch event {
        case .initialSession:
            await checkSession()
        case .signedIn:
            print("🔐 AuthService: サインイン成功 - Event: signedIn")
            if let session = session {
                print("🔐 AuthService: セッション取得成功 - User ID: \(session.user.id)")
            }
            isLoading = false
            errorMessage = nil
            await checkSession()
        case .signedOut:
            print("🔐 AuthService: サインアウト")
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
        } catch {
            print("⚠️ AuthService: セッション確認失敗 - \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    /// Googleでサインイン
    func signInWithGoogle() async throws {
        print("🔐 AuthService: Googleサインイン開始")
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
            ]
            
            guard let authURL = components.url else {
                throw AuthError.signInFailed("Failed to create auth URL")
            }
            
            print("🔐 AuthService: OAuth URL作成 - \(authURL)")
            
            // ASWebAuthenticationSessionを使用してOAuthフローを開始
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
                        print("❌ AuthService: コールバックURLがnil")
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
            
            // セッションを保持（deallocationを防ぐ）
            self.oauthSession = session
            
            let started = session.start()
            if !started {
                throw AuthError.signInFailed("Failed to start OAuth session")
            }
            
            print("🔐 AuthService: Google OAuthセッション開始完了")
            // 注意: OAuthフローは非同期に進行し、コールバックURLが処理されるとhandleOAuthCallbackが呼ばれる
            // isLoadingはhandleOAuthCallbackまたはエラー時にfalseに設定される
        } catch {
            print("❌ AuthService: Googleサインインエラー - \(error.localizedDescription)")
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
            print("❌ AuthService: トークンが見つかりません")
            isLoading = false
            errorMessage = "Tokens not found in callback"
            return
        }
        
        let expiresIn = Int(params["expires_in"] ?? "3600") ?? 3600
        let tokenType = params["token_type"] ?? "bearer"
        
        AppLogger.info("トークン取得成功", category: .auth)
        AppLogger.logToken("Access Token", token: accessToken, category: .auth)
        AppLogger.logToken("Refresh Token", token: refreshToken, category: .auth)
        AppLogger.debug("Expires In: \(expiresIn)", category: .auth)
        
        // セッションを設定
        do {
            // Supabase Swift SDKのsetSessionメソッドを使用
            // アクセストークンとリフレッシュトークンからセッションを作成
            let session = try await supabase.auth.setSession(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
            
            print("✅ AuthService: セッション設定成功")
            print("   - User ID: \(session.user.id)")
            print("   - Email: \(session.user.email ?? "N/A")")
            
            isLoading = false
            errorMessage = nil
            await checkSession()
        } catch {
            print("❌ AuthService: セッション設定エラー - \(error.localizedDescription)")
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    /// URLからOAuthコールバックを処理（lecsyApp.swiftから呼ばれる）
    func handleOAuthCallbackURL(_ url: URL) async {
        await handleOAuthCallback(callbackURL: url)
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
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }
    
    /// セッションをリフレッシュ
    func refreshSession() async {
        do {
            print("🔄 AuthService: セッションをリフレッシュ中...")
            let session = try await supabase.auth.refreshSession()
            print("✅ AuthService: セッションリフレッシュ成功 - User ID: \(session.user.id)")
            await checkSession()
        } catch {
            print("❌ AuthService: セッションリフレッシュ失敗 - \(error.localizedDescription)")
            // エラーが発生した場合でも、既存のセッションを確認
            await checkSession()
        }
    }
    
    /// アクセストークンを取得
    var accessToken: String? {
        get async {
            do {
                let session = try await supabase.auth.session
                return session.accessToken
            } catch {
                return nil
            }
        }
    }
    
    /// セッションが有効か確認
    var isSessionValid: Bool {
        get async {
            do {
                _ = try await supabase.auth.session
                return true
            } catch {
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
                    let session = try await supabase.auth.signInWithIdToken(
                        credentials: .init(
                            provider: .apple,
                            idToken: identityTokenString,
                            nonce: nonce
                        )
                    )
                    
                    // 初回サインイン時のみ、fullNameを保存
                    if let fullName = appleIDCredential.fullName {
                        let name = [fullName.givenName, fullName.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        
                        if !name.isEmpty {
                            // ユーザーメタデータを更新
                            _ = try? await supabase.auth.update(user: UserAttributes(data: ["full_name": AnyJSON.string(name)]))
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
                    print("❌ AuthService: Appleサインイン処理エラー - \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
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
        // 最新のiOS APIを使用
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            print("🍎 AuthService: Found key window")
            return window
        }
        // フォールバック（iOS 13以前のサポート）
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            print("🍎 AuthService: Found key window (fallback)")
            return window
        }
        // 最終フォールバック
        print("🍎 AuthService: Using fallback window")
        return UIWindow()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // @MainActorが設定されているため、メインスレッドで実行される
        // 最新のiOS APIを使用
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // フォールバック（iOS 13以前のサポート）
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // 最終フォールバック
        return UIWindow()
    }
}

/// 認証エラー
enum AuthError: LocalizedError {
    case signInFailed(String)
    case signOutFailed(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "ログインに失敗しました: \(message)"
        case .signOutFailed(let message):
            return "ログアウトに失敗しました: \(message)"
        case .notAuthenticated:
            return "ユーザーが認証されていません"
        }
    }
}
