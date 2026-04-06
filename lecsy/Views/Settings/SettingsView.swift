//
//  SettingsView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var transcriptionService = TranscriptionService.shared
    @StateObject private var orgService = OrganizationService.shared
    @State private var showReportSheet = false

    var body: some View {
        NavigationView {
            List {
                // Organization section
                Section {
                    // B2B Demo Mode toggle
                    Toggle(isOn: $orgService.isDemoMode) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("B2B Demo Mode")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Enable organization features")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if orgService.isInOrganization {
                        // Current org info
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(orgService.currentOrganization?.name ?? "")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("\(orgService.currentRole?.displayName ?? "") • \(orgService.activeMembers.count) members")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        // Switch org if multiple
                        if orgService.organizations.count > 1 {
                            ForEach(orgService.organizations.filter { $0.id != orgService.currentOrganization?.id }) { org in
                                Button {
                                    orgService.switchOrganization(to: org)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.secondary.opacity(0.08))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        Text("Switch to \(org.name)")
                                            .font(.system(.body, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.secondary.opacity(0.4))
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Organization", systemImage: "building.2")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                }

                // Support section
                Section {
                    Button {
                        showReportSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                            }
                            Text("Report a Problem")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                } header: {
                    Label("Support", systemImage: "questionmark.circle")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                }

                // Privacy section
                Section {
                    if let url = URL(string: "https://lecsy.app/privacy") {
                        Link(destination: url) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                                Text("Privacy Policy")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                    }

                    if let url = URL(string: "https://lecsy.app/terms") {
                        Link(destination: url) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.purple.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.purple)
                                }
                                Text("Terms of Service")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                    }
                } header: {
                    Label("Privacy", systemImage: "lock.shield")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                }

                // About section
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 32, height: 32)
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Text("Version")
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showReportSheet) {
                ReportSheet()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var availableLanguages: [TranscriptionLanguage] {
        if transcriptionService.isMultilingualKitInstalled {
            return TranscriptionLanguage.allCases
        }
        return TranscriptionLanguage.baseLanguages
    }
}

private func formatDownloadElapsed(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

#Preview {
    SettingsView()
}
