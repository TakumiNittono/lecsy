//
//  ContentView.swift
//  lecsy
//
//  Created by Takuminittono on 2026/01/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var orgService = OrganizationService.shared

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

                if orgService.isInOrganization {
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
                    .tag(orgService.isInOrganization ? 3 : 2)
            }
            .onReceive(NotificationCenter.default.publisher(for: .lectureRecordingCompleted)) { _ in
                // Auto-switch to Library after saving a recording
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { selectedTab = 1 }
                }
            }

            // Org joined toast
            if orgService.showJoinedToast {
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
    }
}

#Preview {
    ContentView()
}
