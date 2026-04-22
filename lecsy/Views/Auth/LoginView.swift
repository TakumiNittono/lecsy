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

    // Magic link (email OTP) state.
    // Why this exists: see AuthService.swift "Magic Link" section. TL;DR —
    // international students from China can't always use Google Sign In, and
    // the B2B CSV invite flow needs an email-based authentication path.
    @State private var emailInput: String = ""
    @State private var otpCodeInput: String = ""
    @State private var magicLinkStage: MagicLinkStage = .email
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var otpFieldFocused: Bool

    // Invite code (classroom pilot path — see AuthService.signInWithInviteCode
    // for why email can't be the primary flow at FMCC / Santa Fe).
    @State private var inviteCodeInput: String = ""
    @FocusState private var inviteCodeFieldFocused: Bool

    private enum MagicLinkStage {
        case email     // Show email field + Send Code button
        case codeEntry // Show OTP field + Verify button (after email sent)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                // sheet / navigation bar が既に上部チャームを担うので、ここでは最小 margin のみ。
                // 各要素サイズも iPad モーダル幅に合わせてコンパクト化 (以前は旧 full-screen 設計
                // の頃のまま巨大で、モーダル中では1画面に収まらずスクロールが必須だった)。
                VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
                    // アプリロゴ・タイトル (コンパクト版)
                    VStack(spacing: horizontalSizeClass == .regular ? 10 : 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: horizontalSizeClass == .regular ? 44 : 40))
                            .foregroundColor(.blue)

                        Text("Lecsy")
                            .font(.system(size: horizontalSizeClass == .regular ? 30 : 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Record lectures and transcribe automatically")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, horizontalSizeClass == .regular ? 4 : 0)

                // ログインボタン
                // 以下の各 button / input は全て 375pt 上限 + 中央寄せに統一する。
                // Apple Sign-In ボタンは HIG で内部的に 375 上限がかかっているため、
                // Google / Join class / Continue without login 等を同じ上限に揃えないと
                // iPhone で Apple だけ狭く見える違和感が出る (iPad sheet 内でも同様)。
                VStack(spacing: 12) {
                    // ── Invite code (classroom pilot primary path) ──
                    // メールが届かない / 学校 Microsoft 365 が Junk に飛ばす
                    // 問題を回避するため、教員が紙 or QR で配る 6-digit コードで
                    // anonymous サインイン + org 参加を一発で済ませる。
                    inviteCodeSection

                    HStack {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                        Text("OR SIGN IN")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .kerning(1.0)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                    }
                    .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)

                    // Microsoft ボタンは一時非表示。
                    // US 大学 / コミカレ (Santa Fe, FMCC 等) の Entra ID テナントは
                    // 「未検証 multitenant アプリへの end-user consent をブロック」が
                    // デフォルト設定のため、学生が押しても admin 承認要求画面に
                    // 飛んで当日は通らない。admin consent or Verified Publisher 化
                    // が済んだら下記 `if false` を外して復活。
                    // AuthService.signInWithMicrosoft() / signInWithMicrosoft() ローカル
                    // helper の実装は温存 (フリップだけで復活可能)。
                    if false {
                        Button(action: {
                            Task { await signInWithMicrosoft() }
                        }) {
                            HStack(spacing: 12) {
                                // Microsoft 4-color logo (orange / green / blue / yellow squares)
                                HStack(spacing: 2) {
                                    VStack(spacing: 2) {
                                        Rectangle().fill(Color(red: 0.95, green: 0.32, blue: 0.13)).frame(width: 9, height: 9)
                                        Rectangle().fill(Color(red: 0.0, green: 0.65, blue: 0.31)).frame(width: 9, height: 9)
                                    }
                                    VStack(spacing: 2) {
                                        Rectangle().fill(Color(red: 0.0, green: 0.46, blue: 0.84)).frame(width: 9, height: 9)
                                        Rectangle().fill(Color(red: 1.0, green: 0.72, blue: 0.0)).frame(width: 9, height: 9)
                                    }
                                }
                                Text("Continue with Microsoft")
                                    .font(.headline)
                            }
                            .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
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
                        .accessibilityLabel("Sign in with Microsoft")
                    }

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
                    .frame(height: 44)
                    // ASAuthorizationAppleIDButton は内部で width <= 375 の制約を
                    // 持っている (Apple HIG)。外側が 400+ だと constraint 競合ログ
                    // が出るので、ここで 375 に揃える。iPad では中央寄せで余白になる。
                    .frame(maxWidth: 375)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .cornerRadius(10)
                    .disabled(authService.isLoading)

                // Googleログインボタン — Apple button と同じ 375 centered パターン
                Button(action: {
                    Task {
                        await signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                        Text("Continue with Google")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(authService.isLoading)

                // Continue without login — 同じ 375 centered パターンに統一
                Button(action: {
                    authService.skipLogin()
                }) {
                    Text("Continue without login")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(10)
                }
                .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(authService.isLoading)

                // ── Divider ──
                HStack {
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
                }
                .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)

                // ── Email magic link ──
                magicLinkSection
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
            
            if let errorMessage = errorMessage ?? authService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            if authService.isLoading {
                ProgressView()
                    .padding(.top, 8)
            }
                }
                .padding(.top, horizontalSizeClass == .regular ? 16 : 12)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var inviteCodeSection: some View {
        VStack(spacing: 8) {
            // 1行見出し (以前は縦 2行使ってた heading + 説明文 を統合)
            HStack(spacing: 6) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text("Have an invite code?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("· 6 digits on your card")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)

            TextField("000000", text: $inviteCodeInput)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .tracking(6)
                .focused($inviteCodeFieldFocused)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
                .onChange(of: inviteCodeInput) { _, newValue in
                    // Digits only, capped at 6. Auto-submit when the sixth
                    // digit lands so students on a number pad don't have to
                    // reach for "Join class" — matches the magic-link OTP UX.
                    let digits = String(newValue.filter { $0.isNumber }.prefix(6))
                    if digits != newValue { inviteCodeInput = digits }
                    if digits.count == 6 && !authService.isLoading {
                        Task { await joinWithInviteCode() }
                    }
                }

            Button {
                Task { await joinWithInviteCode() }
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 15))
                    Text("Join class").font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 44)
                .background(
                    inviteCodeInput.count == 6 ? Color.blue : Color.blue.opacity(0.4)
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(authService.isLoading || inviteCodeInput.count != 6)
        }
    }

    @ViewBuilder
    private var magicLinkSection: some View {
        VStack(spacing: 10) {
            switch magicLinkStage {
            case .email:
                TextField("Email", text: $emailInput)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($emailFieldFocused)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    Task { await sendMagicLink() }
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill").font(.system(size: 15))
                        Text("Send code to email").font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 44)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(authService.isLoading || emailInput.trimmingCharacters(in: .whitespaces).isEmpty)

            case .codeEntry:
                VStack(spacing: 4) {
                    Text("We sent a code to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(emailInput)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }

                TextField("000000", text: $otpCodeInput)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .focused($otpFieldFocused)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
                    .onChange(of: otpCodeInput) { _, newValue in
                        // Auto-submit when 6 digits are entered
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count >= 6 {
                            otpCodeInput = String(digits.prefix(6))
                            Task { await verifyCode() }
                        }
                    }

                HStack(spacing: 16) {
                    Button("Use a different email") {
                        magicLinkStage = .email
                        otpCodeInput = ""
                        errorMessage = nil
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("Resend code") {
                        Task { await sendMagicLink() }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .disabled(authService.isLoading)
                }
                .frame(maxWidth: 375)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func sendMagicLink() async {
        errorMessage = nil
        do {
            try await authService.sendMagicLink(email: emailInput)
            magicLinkStage = .codeEntry
            otpCodeInput = ""
            // Slight delay so the focus change feels intentional
            try? await Task.sleep(nanoseconds: 200_000_000)
            otpFieldFocused = true
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    private func verifyCode() async {
        errorMessage = nil
        do {
            try await authService.verifyMagicLinkCode(email: emailInput, code: otpCodeInput)
            // authStateChanges listener will flip isAuthenticated and dismiss
            // this view via the parent navigator
        } catch {
            errorMessage = ErrorMessages.friendly(error)
            // Don't reset stage — let user retry the code
        }
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
                    errorMessage = ErrorMessages.friendly(error)
                }
            } else {
                errorMessage = ErrorMessages.friendly(error)
            }
            
            currentNonce = nil
        }
    }
    
    private func signInWithGoogle() async {
        errorMessage = nil

        do {
            try await authService.signInWithGoogle()
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    private func signInWithMicrosoft() async {
        errorMessage = nil
        do {
            try await authService.signInWithMicrosoft()
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    private func joinWithInviteCode() async {
        errorMessage = nil
        do {
            try await authService.signInWithInviteCode(inviteCodeInput)
        } catch {
            errorMessage = ErrorMessages.friendly(error)
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
            
            errorMessage = ErrorMessages.friendly(error)
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
