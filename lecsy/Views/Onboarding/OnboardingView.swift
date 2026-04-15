//
//  OnboardingView.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import SwiftUI
import UIKit

struct OnboardingView: View {
    @AppStorage("lecsy.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("lecsy.hasAcceptedAIConsent") private var hasAcceptedAIConsent = false
    @StateObject private var transcriptionService = TranscriptionService.shared
    @StateObject private var authService = AuthService.shared
    @State private var currentPage = 0
    @State private var selectedLanguage: TranscriptionLanguage = .english
    @State private var elapsedSeconds: Int = 0
    @State private var setupTimer: Timer?
    @State private var showSignInSuccess = false

    private let totalPages = 5
    private let authPageIndex = 4
    private let estimatedSeconds: Double = 90

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    privacyPage.tag(0)
                    howItWorksPage.tag(1)
                    featuresPage.tag(2)
                    languagePage.tag(3)
                    authPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                bottomSection
            }

            // Sign-in success overlay
            if showSignInSuccess {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 96, height: 96)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                    }
                    Text("Sign-in Successful!")
                        .font(.title2.bold())
                    if let email = authService.currentUser?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(36)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startSetupTimer()
            // Ensure model preloading has started (safety net in case init was skipped)
            if !transcriptionService.isModelLoaded {
                transcriptionService.prepareModelInBackground(force: true)
            }
        }
        .onDisappear { stopSetupTimer() }
        // Auto-complete onboarding once user has signed in (or skipped) AND
        // the AI model is loaded — both conditions met means we're ready.
        .onChange(of: authService.isAuthenticated) { _, _ in
            tryFinishIfReady()
        }
        .onChange(of: authService.hasSkippedLogin) { _, _ in
            tryFinishIfReady()
        }
        .onChange(of: transcriptionService.isModelLoaded) { _, _ in
            tryFinishIfReady()
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Auth page renders its own buttons (Apple/Google/Skip)
            if currentPage == authPageIndex {
                EmptyView()
            } else {
            Button(action: nextAction) {
                Text(buttonText)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.blue : Color.secondary.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canProceed)
            } // end of non-auth-page button branch

            if currentPage == 0 {
                if let url = URL(string: "https://lecsy.app/privacy") {
                    Link("Privacy Policy", destination: url)
                        .font(.subheadline)
                }
            } else if currentPage < totalPages - 1 && currentPage != authPageIndex {
                Button("Skip") {
                    withAnimation { currentPage = totalPages - 1 }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 500)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private var canProceed: Bool {
        if currentPage == 0 {
            return true
        }
        return true
    }

    private var buttonText: String {
        if currentPage == 0 { return "Agree & Continue" }
        return "Next"
    }

    private func tryFinishIfReady() {
        // Show the success toast as soon as the user signs in, but DO NOT
        // advance past the onboarding/download screen until the AI model
        // has finished loading. We want users to see download progress.
        if authService.isAuthenticated && !showSignInSuccess {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSignInSuccess = true
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            // Auto-hide the toast after 1.4s so the download UI is visible again.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSignInSuccess = false
                }
            }
        }

        // Only actually finish onboarding when BOTH:
        //   - the user has signed in (or explicitly skipped), AND
        //   - the AI model has finished downloading/loading.
        let authedOrSkipped = authService.isAuthenticated || authService.hasSkippedLogin
        if authedOrSkipped && transcriptionService.isModelLoaded {
            completeOnboarding()
        }
    }

    private func nextAction() {
        if currentPage == 0 {
            hasAcceptedAIConsent = true
        }
        if currentPage == 3 {
            transcriptionService.setLanguage(selectedLanguage)
        }
        if currentPage < totalPages - 1 {
            withAnimation { currentPage += 1 }
        } else {
            completeOnboarding()
        }
    }

    // MARK: - Page 1: Privacy

    private var privacyPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("How Your Audio Is Handled")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 14) {
                    iconRow(icon: "iphone",
                            text: "Transcription runs on your iPhone. Your audio stays on your device.")
                    iconRow(icon: "cloud.slash",
                            text: "We never upload your recordings. Only transcript text can be saved to your account, and only if you choose to.")
                    iconRow(icon: "building.2",
                            text: "Organizations can opt in to cloud transcription. In that case audio is processed transiently and never stored by Lecsy.")
                    iconRow(icon: "lock.shield",
                            text: "Your content is yours. We never train AI models on your data.")
                }
                .padding(.horizontal, 32)

                Text("See our Privacy Policy at lecsy.app/privacy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Page 2: How It Works

    private var howItWorksPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("How It Works")
                    .font(.title.bold())

                VStack(spacing: 24) {
                    stepCard(step: "1", icon: "mic.fill", color: .red,
                             title: "Record",
                             desc: "Tap the mic button to start recording your lecture. Pause and resume anytime.")
                    stepCard(step: "2", icon: "cpu", color: .blue,
                             title: "On-Device Transcription",
                             desc: "After recording, your iPhone transcribes the audio locally. Works offline — your audio never leaves your device.")
                    stepCard(step: "3", icon: "doc.text.magnifyingglass", color: .green,
                             title: "Review",
                             desc: "Read, search, and copy your transcription. Export as text, Markdown, or PDF.")
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Page 3: Features

    private var featuresPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Powerful Features")
                    .font(.title.bold())

                VStack(spacing: 20) {
                    featureCard(icon: "airplane", color: .orange,
                                title: "Works Offline",
                                desc: "Record and transcribe without internet. Perfect for lecture halls with bad Wi-Fi.")
                    featureCard(icon: "bookmark.fill", color: .purple,
                                title: "Bookmarks",
                                desc: "Mark important moments during recording. Jump back to key points instantly.")
                    featureCard(icon: "globe", color: .blue,
                                title: "12 Languages",
                                desc: "English, Japanese, Korean, Chinese, Spanish, French, and more.")
                    featureCard(icon: "square.and.arrow.up", color: .green,
                                title: "Export Anywhere",
                                desc: "Share your transcriptions as text, Markdown, or PDF.")
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Page 4: Language Selection

    private var languagePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "globe")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Choose Your Language")
                    .font(.title.bold())

                Text("What language are your lectures in?\nYou can change this anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(TranscriptionLanguage.allCases, id: \.self) { lang in
                        languageButton(lang)
                    }
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
        }
    }

    private func languageButton(_ lang: TranscriptionLanguage) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedLanguage = lang
            }
        } label: {
            Text(lang.displayName)
                .font(.subheadline.weight(selectedLanguage == lang ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedLanguage == lang ? Color.blue : Color.secondary.opacity(0.08))
                .foregroundStyle(selectedLanguage == lang ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Page 5: Sign In + AI download progress (concurrent)

    @ViewBuilder
    private var authPage: some View {
        VStack(spacing: 0) {
            if authService.isAuthenticated {
                // Already signed in — show only the signed-in waiting view
                // (which has its own progress bar). Skip the top banner so
                // we don't end up with two progress bars.
                signedInWaitingView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                modelDownloadBanner
                LoginView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var signedInWaitingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
            }
            Text("Signed in")
                .font(.title2.bold())
            if let email = authService.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer().frame(height: 16)
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cpu").foregroundStyle(.blue)
                    Text(transcriptionService.isModelLoaded
                         ? "AI model ready"
                         : "Setting up AI…")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(setupProgress * 100))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                ProgressView(value: setupProgress).tint(.blue)
                Text(transcriptionService.isModelLoaded
                     ? "Ready to go!"
                     : estimatedTimeRemaining)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    @ViewBuilder
    private var modelDownloadBanner: some View {
        if transcriptionService.isModelLoaded {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("AI model ready")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.08))
        } else {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "cpu").foregroundStyle(.blue)
                    Text("Setting up AI in background…")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text("\(Int(setupProgress * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
                ProgressView(value: setupProgress).tint(.blue)
                Text("You can sign in while it loads.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.06))
        }
    }

    private var setupProgress: Double {
        if transcriptionService.isModelLoaded { return 1.0 }
        let t = Double(elapsedSeconds)
        let est = estimatedSeconds

        if t < est * 0.7 {
            // 0-70% of time: steady progress 0→75%
            return (t / (est * 0.7)) * 0.75
        } else if t < est {
            // 70-100% of time: slower progress 75→92%
            let phase = (t - est * 0.7) / (est * 0.3)
            return 0.75 + phase * 0.17
        } else {
            // Over estimate: keep creeping, never stop
            // Goes from 92% → approaches 99%, always moving
            let overtime = t - est
            return 0.92 + 0.07 * (1 - 1 / (1 + overtime / 30))
        }
    }

    private var estimatedTimeRemaining: String {
        if transcriptionService.isModelLoaded { return "Complete" }
        let elapsed = Double(elapsedSeconds)
        let est = estimatedSeconds

        if elapsed < est * 0.8 {
            let remaining = Int(est - elapsed)
            if remaining >= 60 {
                return "About \(remaining / 60) min \(remaining % 60)s remaining"
            }
            return "About \(remaining)s remaining"
        } else {
            return "Almost done..."
        }
    }

    private func startSetupTimer() {
        stopSetupTimer()
        setupTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if !transcriptionService.isModelLoaded {
                    elapsedSeconds += 1
                }
            }
        }
    }

    private func stopSetupTimer() {
        setupTimer?.invalidate()
        setupTimer = nil
    }

    // MARK: - Reusable Components

    private func iconRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepCard(step: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func featureCard(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func completeOnboarding() {
        hasSeenOnboarding = true
    }
}

#Preview {
    OnboardingView()
}
