//
//  OnboardingView.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("lecsy.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("lecsy.hasAcceptedAIConsent") private var hasAcceptedAIConsent = false
    @StateObject private var transcriptionService = TranscriptionService.shared
    @State private var currentPage = 0
    @State private var selectedLanguage: TranscriptionLanguage = .english
    @State private var elapsedSeconds: Int = 0
    @State private var setupTimer: Timer?

    private let totalPages = 5
    private let estimatedSeconds: Double = 90

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                privacyPage.tag(0)
                howItWorksPage.tag(1)
                featuresPage.tag(2)
                languagePage.tag(3)
                readyPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            bottomSection
        }
        .onAppear {
            startSetupTimer()
            // Ensure model preloading has started (safety net in case init was skipped)
            if !transcriptionService.isModelLoaded {
                transcriptionService.prepareModelInBackground(force: true)
            }
        }
        .onDisappear { stopSetupTimer() }
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

            if currentPage == 0 {
                if let url = URL(string: "https://lecsy.app/privacy") {
                    Link("Privacy Policy", destination: url)
                        .font(.subheadline)
                }
            } else if currentPage < totalPages - 1 {
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
        // Require AI consent on first page
        if currentPage == 0 {
            return true // Tapping "Agree & Continue" itself gives consent
        }
        // Block final page until model is loaded
        if currentPage == totalPages - 1 {
            return transcriptionService.isModelLoaded
        }
        return true
    }

    private var buttonText: String {
        switch currentPage {
        case 0: return "Agree & Continue"
        case 4:
            return transcriptionService.isModelLoaded ? "Get Started" : "Preparing AI..."
        default: return "Next"
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

                Text("Your Privacy Matters")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 14) {
                    iconRow(icon: "cpu", text: "All AI transcription runs on-device. No third-party AI service is used.")
                    iconRow(icon: "iphone", text: "Your audio recordings never leave your device.")
                    iconRow(icon: "wifi", text: "No internet needed for transcription. Everything works offline.")
                    iconRow(icon: "lock.shield", text: "Your recordings and transcriptions stay on your device. Nothing is uploaded.")
                }
                .padding(.horizontal, 32)

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
                             title: "Transcribe",
                             desc: "AI automatically converts speech to text, entirely on your device.")
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

                Text("Built for Students")
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

    // MARK: - Page 5: Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            if transcriptionService.isModelLoaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))

                Text("You're All Set!")
                    .font(.title.bold())

                Text("Start recording your first lecture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if transcriptionService.state == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("Setup Failed")
                    .font(.title.bold())

                Text("Couldn't prepare the AI model.\nPlease try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    elapsedSeconds = 0
                    transcriptionService.prepareModelInBackground(force: true)
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Setting Up AI")
                    .font(.title.bold())

                Text("Optimizing for your device.\nThis only happens once.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Progress bar + time
                VStack(spacing: 8) {
                    ProgressView(value: setupProgress)
                        .tint(.blue)
                        .scaleEffect(y: 2)

                    HStack {
                        Text(estimatedTimeRemaining)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(setupProgress * 100))%")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 48)

                // Tips while waiting
                VStack(alignment: .leading, spacing: 14) {
                    iconRow(icon: "lightbulb.fill",
                            text: "Place your device near the speaker for the best transcription quality.")
                    iconRow(icon: "hand.tap.fill",
                            text: "Tap the bookmark button during recording to mark important moments.")
                    iconRow(icon: "pause.circle.fill",
                            text: "You can pause and resume recording anytime.")
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .animation(.easeInOut(duration: 0.5), value: transcriptionService.isModelLoaded)
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
