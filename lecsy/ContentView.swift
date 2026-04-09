//
//  ContentView.swift
//  lecsy
//
//  Created by Takuminittono on 2026/01/26.
//

import SwiftUI

// B2B (Organization) features are hidden for the "Free Until June 1" B2C launch.
// Toggle this to `true` to resurface the Org tab after the LLC is set up and
// school partnerships resume. Keeping the code compiled prevents bit-rot.
private let kB2BEnabled = false

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var orgService = OrganizationService.shared
    // Observe the transcription service so the multilingual-kit download
    // can show a full-screen cover that blocks tab switching. Previously
    // the download UI was inline in Settings, so users who tapped another
    // tab mid-download (e.g. ~86s in) would lose the progress view and
    // think the download had been abandoned, when in fact it was still
    // running in the background.
    @StateObject private var transcriptionService = TranscriptionService.shared

    private var showOrgTab: Bool {
        kB2BEnabled && orgService.isInOrganization
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecordView()
                    .tabItem {
                        Label("Record", systemImage: "mic.fill")
                    }
                    .tag(0)
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
                    .tag(1)

                if showOrgTab {
                    OrganizationTabView()
                        .tabItem {
                            Label("Org", systemImage: "building.2.fill")
                        }
                        .tag(2)
                }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    // Stable tag independent of whether Org tab is visible.
                    // Using a dynamic tag caused the selected tab to jump when
                    // `showOrgTab` flipped at runtime (e.g., joining/leaving an org).
                    .tag(99)
            }
            .onReceive(NotificationCenter.default.publisher(for: .lectureRecordingCompleted)) { _ in
                // Auto-switch to Library after saving a recording
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { selectedTab = 1 }
                }
            }

            // Org joined toast (suppressed while B2B is disabled)
            if kB2BEnabled && orgService.showJoinedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.caption)
                        Text("Joined \(orgService.joinedOrgName)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    
                    .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                

            
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { orgService.showJoinedToast = false }
                    }
                }
            }
        }
        // Full-screen blocking cover for the multilingual-kit download.
        // Uses `fullScreenCover` so the user physically cannot switch
        // tabs or leave this screen until the download finishes. The
        // sheet has NO dismiss button — it auto-dismisses when
        // `isDownloadingMultilingualKit` flips back to false.
        // Read-only binding: the cover's presentation state is driven
        // entirely by the service. SwiftUI's dismiss path must be a no-op
        // so nothing can close this view before the download finishes.
        .fullScreenCover(isPresented: Binding(
            get: { transcriptionService.isDownloadingMultilingualKit },
            set: { _ in /* ignore — only the service flips this */ }
        )) {
            MultilingualKitDownloadBlockingView(service: transcriptionService)
                .interactiveDismissDisabled(true)
        }
    }
}

/// Blocking progress view shown during the ~86s multilingual kit download.
/// Cannot be dismissed by the user — auto-closes when the service flips
/// `isDownloadingMultilingualKit` back to false (success or failure).
private struct MultilingualKitDownloadBlockingView: View {
    @ObservedObject var service: TranscriptionService

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "globe")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Adding more languages")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("日本語, 한국어, 中文, Español and more")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }

                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 4)

                VStack(spacing: 4) {
                    Text(service.downloadStatusText.isEmpty ? "Preparing…" : service.downloadStatusText)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if service.downloadElapsedSeconds > 0 {
                        Text(formattedElapsed(service.downloadElapsedSeconds))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }

                Text("Please keep the app open until the download finishes. This only happens once.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
            .padding(32)
        }
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d elapsed", m, s) : "\(s)s elapsed"
    }
}

#Preview {
    ContentView()
}
