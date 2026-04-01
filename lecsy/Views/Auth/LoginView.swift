//
//  LoginView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                Spacer()
                
                // アプリロゴ・タイトル
                VStack(spacing: 16) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 100 : 80))
                        .foregroundColor(.blue)
                    
                    Text("Lecsy")
                        .font(.system(size: horizontalSizeClass == .regular ? 56 : 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Record lectures and transcribe automatically")
                        .font(horizontalSizeClass == .regular ? .title3 : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // ログインボタン
                VStack(spacing: 16) {
                    // Appleログインボタン（Appleのデザインガイドラインに準拠）
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            // nonceを生成してリクエストに設定
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                            AppLogger.info("LoginView: Apple Sign In request created", category: .auth)
                        },
                        onCompletion: { result in
                            handleAppleSignInCompletion(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
                    .cornerRadius(12)
                    .disabled(authService.isLoading)
                
                // Googleログインボタン
                Button(action: {
                    Task {
                        await signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(authService.isLoading)
                
                // Skip button - allows using app without account
                Button(action: {
                    authService.skipLogin()
                }) {
                    Text("Continue without account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .disabled(authService.isLoading)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 80 : 40)
            
            if let errorMessage = errorMessage ?? authService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            if authService.isLoading {
                ProgressView()
                    .padding(.top, 16)
            }
            
            Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
    
    /// Apple Sign Inの完了を処理
    private func handleAppleSignInCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            AppLogger.info("LoginView: Apple Sign In succeeded, processing authorization", category: .auth)
            Task {
                await handleAppleSignInResult(authorization: authorization)
            }
        case .failure(let error):
            AppLogger.error("LoginView: Apple Sign In failed - \(error.localizedDescription)", category: .auth)

            // ASAuthorizationErrorを詳細に解析
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    AppLogger.debug("LoginView: User canceled the authorization", category: .auth)
                    errorMessage = nil // ユーザーがキャンセルした場合はエラーを表示しない
                case .failed:
                    AppLogger.error("LoginView: Authorization failed", category: .auth)
                    errorMessage = "Sign in failed. Please try again."
                case .invalidResponse:
                    AppLogger.error("LoginView: Invalid response from Apple", category: .auth)
                    errorMessage = "Invalid response from Apple. Please try again."
                case .notHandled:
                    AppLogger.error("LoginView: Authorization not handled", category: .auth)
                    errorMessage = "Authorization not handled. Please try again."
                case .unknown:
                    AppLogger.error("LoginView: Unknown error", category: .auth)
                    errorMessage = "An unknown error occurred. Please try again."
                case .notInteractive:
                    AppLogger.error("LoginView: Not interactive", category: .auth)
                    errorMessage = "Interactive sign in required."
                @unknown default:
                    AppLogger.error("LoginView: Unknown error case", category: .auth)
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
            
            currentNonce = nil
        }
    }
    
    private func signInWithGoogle() async {
        errorMessage = nil
        
        do {
            try await authService.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleAppleSignInResult(authorization: ASAuthorization) async {
        AppLogger.info("LoginView: Apple Sign In authorization received", category: .auth)
        errorMessage = nil
        
        AppLogger.debug("LoginView: Checking authorization credential type", category: .auth)
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            AppLogger.error("LoginView: Failed to cast credential to ASAuthorizationAppleIDCredential", category: .auth)
            errorMessage = "Apple authentication failed"
            currentNonce = nil
            return
        }
        AppLogger.info("LoginView: Successfully cast to ASAuthorizationAppleIDCredential", category: .auth)

        AppLogger.debug("LoginView: Extracting identity token", category: .auth)
        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            AppLogger.error("LoginView: Failed to extract identity token", category: .auth)
            errorMessage = "Failed to retrieve token"
            currentNonce = nil
            return
        }
        AppLogger.info("LoginView: Identity token extracted", category: .auth)
        
        // リクエスト時に設定したnonceを使用（元のnonce、ハッシュ化前）
        AppLogger.debug("LoginView: Checking nonce", category: .auth)
        guard let nonce = currentNonce else {
            errorMessage = "Nonce not found"
            AppLogger.error("LoginView: Nonce is nil", category: .auth)
            return
        }
        AppLogger.debug("LoginView: Nonce verified", category: .auth)

        do {
            AppLogger.debug("LoginView: Calling AuthService.handleAppleSignIn", category: .auth)
            // AuthServiceのhandleAppleSignInメソッドを使用
            try await authService.handleAppleSignIn(
                identityToken: identityTokenString,
                nonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            currentNonce = nil
            AppLogger.info("LoginView: Apple Sign In completed successfully", category: .auth)
        } catch {
            currentNonce = nil
            AppLogger.error("LoginView: Apple Sign In error - \(error.localizedDescription)", category: .auth)
            
            errorMessage = error.localizedDescription
        }
    }
    
    // nonce生成用のヘルパー関数
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
                    // Fallback to arc4random if SecRandomCopyBytes fails
                    random = UInt8(arc4random_uniform(UInt32(UInt8.max) + 1))
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
    
    // SHA256ハッシュ生成用のヘルパー関数
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

#Preview {
    LoginView()
}
