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
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // アプリロゴ・タイトル
            VStack(spacing: 16) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Lecsy")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("講義を録音して、自動で文字起こし")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // ログインボタン
            VStack(spacing: 16) {
                // Appleログインボタン（Appleのデザインガイドラインに準拠）
                SignInWithAppleButton(
                    onRequest: { request in
                        // nonceを生成してリクエストに設定
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                        print("🍎 LoginView: Apple Sign In request created with nonce")
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task {
                                await handleAppleSignInResult(authorization: authorization)
                            }
                        case .failure(let error):
                            print("❌ Apple Sign In error: \(error.localizedDescription)")
                            currentNonce = nil
                            errorMessage = error.localizedDescription
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
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
                        Text("Googleで続ける")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
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
            }
            .padding(.horizontal, 40)
            
            if let errorMessage = errorMessage ?? authService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            if authService.isLoading {
                ProgressView()
                    .padding(.top, 16)
            }
            
            Spacer()
        }
        .padding()
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
        print("🍎 LoginView: Apple Sign In authorization received")
        errorMessage = nil
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Apple認証に失敗しました"
            currentNonce = nil
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "トークンの取得に失敗しました"
            currentNonce = nil
            return
        }
        
        // リクエスト時に設定したnonceを使用（元のnonce、ハッシュ化前）
        guard let nonce = currentNonce else {
            errorMessage = "Nonceが見つかりません"
            print("❌ LoginView: Nonce is nil")
            return
        }
        
        print("🍎 LoginView: Using nonce - \(nonce.prefix(8))...")
        
        do {
            // Supabaseに送信するnonceは、元のnonce（ハッシュ化前）を送信
            // Supabaseが内部でハッシュ化して、id_tokenに含まれるnonceと比較する
            let session = try await authService.supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityTokenString,
                    nonce: nonce  // 元のnonceを送信（ハッシュ化しない）
                )
            )
            
            // 初回サインイン時のみ、fullNameを保存
            if let fullName = appleIDCredential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !name.isEmpty {
                    // ユーザーメタデータを更新
                    _ = try? await authService.supabase.auth.update(user: UserAttributes(data: ["full_name": AnyJSON.string(name)]))
                }
            }
            
            currentNonce = nil
            print("✅ LoginView: Apple Sign In completed successfully")
            await authService.checkSession()
        } catch {
            currentNonce = nil
            print("❌ LoginView: Apple Sign In error - \(error.localizedDescription)")
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
