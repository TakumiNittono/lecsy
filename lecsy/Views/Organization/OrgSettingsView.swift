//
//  OrgSettingsView.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import SwiftUI

struct OrgSettingsView: View {
    @StateObject private var orgService = OrganizationService.shared

    var body: some View {
        List {
            // Organization Info
            Section("Organization Info") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(orgService.currentOrganization?.name ?? "")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Slug")
                    Spacer()
                    Text(orgService.currentOrganization?.slug ?? "")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Type")
                    Spacer()
                    Text(orgService.currentOrganization?.type.displayName ?? "")
                        .foregroundColor(.secondary)
                }
            }

            // Plan & Billing
            Section("Plan & Billing") {
                HStack {
                    Label("Current Plan", systemImage: "sparkles")
                    Spacer()
                    Text(orgService.currentOrganization?.plan.displayName ?? "")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.purple)
                }
                HStack {
                    Label("Monthly Price", systemImage: "dollarsign.circle")
                    Spacer()
                    Text(orgService.currentOrganization?.plan.monthlyPrice ?? "")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("Max Seats", systemImage: "person.3")
                    Spacer()
                    Text("\(orgService.currentOrganization?.maxSeats ?? 0)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("AI Daily Limit", systemImage: "sparkles")
                    Spacer()
                    Text("\(orgService.currentOrganization?.plan.dailyAILimit ?? 0) / day")
                        .foregroundColor(.secondary)
                }

                Button {
                    // In production: open Stripe customer portal
                } label: {
                    Label("Manage Billing", systemImage: "creditcard")
                }
            }

            // Limits
            Section("Usage Limits") {
                let stats = orgService.usageStats
                HStack {
                    Text("AI Usage Today")
                    Spacer()
                    Text("\(stats.aiUsageToday) / \(stats.aiDailyLimit)")
                        .foregroundColor(stats.aiUsageToday >= stats.aiDailyLimit ? .red : .secondary)
                }
                HStack {
                    Text("Active Seats")
                    Spacer()
                    Text("\(orgService.activeMembers.count) / \(orgService.currentOrganization?.maxSeats ?? 0)")
                        .foregroundColor(.secondary)
                }
            }

            // Danger zone
            if orgService.currentRole?.canDeleteOrg == true {
                Section {
                    Button(role: .destructive) {
                        // In production: confirmation + delete org
                    } label: {
                        Label("Delete Organization", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This action cannot be undone. All organization data will be permanently deleted.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Organization Settings")
    }
}

#Preview {
    NavigationView { OrgSettingsView() }
}
