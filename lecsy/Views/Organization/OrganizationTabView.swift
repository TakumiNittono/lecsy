//
//  OrganizationTabView.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import SwiftUI

struct OrganizationTabView: View {
    @StateObject private var orgService = OrganizationService.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Org header card
                    orgHeaderCard

                    // Quick stats
                    quickStatsGrid

                    // Menu sections based on role
                    menuSection

                    // Recent activity (mock)
                    recentActivitySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(orgService.currentOrganization?.name ?? "Organization")
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Org Header

    private var orgHeaderCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Org icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(orgService.currentOrganization?.name ?? "")
                        .font(.system(.headline, design: .rounded))

                    HStack(spacing: 8) {
                        Label(orgService.currentOrganization?.type.displayName ?? "",
                              systemImage: "graduationcap.fill")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))

                        HStack(spacing: 3) {
                            Image(systemName: orgService.currentRole?.icon ?? "person.fill")
                                .font(.system(size: 10))
                            Text(orgService.currentRole?.displayName ?? "")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Spacer()
            }

            // Plan badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("\(orgService.currentOrganization?.plan.displayName ?? "") Plan")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())

                Spacer()

                Text("\(orgService.activeMembers.count)/\(orgService.currentOrganization?.maxSeats ?? 0) seats")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Stats

    private var quickStatsGrid: some View {
        let stats = orgService.usageStats
        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            statCard(value: "\(stats.todayRecordings)", label: "Today", icon: "mic.fill", color: .blue)
            statCard(value: "\(stats.activeUsersToday)", label: "Active", icon: "person.2.fill", color: .green)
            statCard(value: "\(stats.aiUsageToday)/\(stats.aiDailyLimit)", label: "AI Uses", icon: "sparkles", color: .purple)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 2) {
            // Always visible
            NavigationLink(destination: MemberListView()) {
                menuRow(icon: "person.3.fill", title: "Members",
                        subtitle: "\(orgService.activeMembers.count) active, \(orgService.pendingMembers.count) pending",
                        color: .blue)
            }

            NavigationLink(destination: ClassListView()) {
                menuRow(icon: "books.vertical.fill", title: "Classes",
                        subtitle: "\(orgService.classes.count) classes",
                        color: .indigo)
            }

            NavigationLink(destination: GlossaryView()) {
                menuRow(icon: "text.book.closed.fill", title: "Glossary",
                        subtitle: "\(orgService.glossaryEntries.count) terms",
                        color: .orange)
            }

            if orgService.currentRole?.canViewUsageStats == true {
                NavigationLink(destination: UsageStatsView()) {
                    menuRow(icon: "chart.bar.fill", title: "Usage Statistics",
                            subtitle: "\(orgService.usageStats.weekRecordings) recordings this week",
                            color: .green)
                }
            }

            if orgService.currentRole?.canChangeOrgSettings == true {
                NavigationLink(destination: OrgSettingsView()) {
                    menuRow(icon: "gearshape.fill", title: "Organization Settings",
                            subtitle: "Manage plan, billing, and preferences",
                            color: .gray)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func menuRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(0.8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                activityRow(icon: "mic.fill", color: .blue,
                            text: "Maria Garcia recorded \"TOEFL Practice #12\"",
                            time: "2h ago")
                Divider().padding(.leading, 48)
                activityRow(icon: "text.book.closed.fill", color: .orange,
                            text: "Sarah Johnson generated glossary from \"Business Vocab\"",
                            time: "4h ago")
                Divider().padding(.leading, 48)
                activityRow(icon: "person.badge.plus", color: .green,
                            text: "New Student joined as pending member",
                            time: "Today")
                Divider().padding(.leading, 48)
                activityRow(icon: "chart.bar.fill", color: .purple,
                            text: "12 recordings captured today across 3 classes",
                            time: "Today")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func activityRow(icon: String, color: Color, text: String, time: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(time)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview {
    OrganizationTabView()
}
