//
//  UsageStatsView.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import SwiftUI

struct UsageStatsView: View {
    @StateObject private var orgService = OrganizationService.shared

    // Mock data for charts
    private let weeklyData: [(String, Int)] = [
        ("Mon", 15), ("Tue", 22), ("Wed", 18),
        ("Thu", 25), ("Fri", 20), ("Sat", 5), ("Sun", 2)
    ]

    private let languageData: [(String, Double)] = [
        ("English", 0.72), ("Spanish", 0.15), ("Japanese", 0.08), ("Other", 0.05)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Overview cards
                overviewCards

                // Weekly chart (simplified bar chart)
                weeklyChartSection

                // Language distribution
                languageSection

                // Top users
                topUsersSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Usage Statistics")
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            overviewCard(value: "\(orgService.usageStats.todayRecordings)", label: "Today's Recordings", icon: "mic.fill", color: .blue)
            overviewCard(value: "\(orgService.usageStats.weekRecordings)", label: "This Week", icon: "calendar", color: .green)
            overviewCard(value: "\(orgService.usageStats.monthRecordings)", label: "This Month", icon: "calendar.badge.clock", color: .purple)
            overviewCard(value: "\(orgService.usageStats.activeUsersToday)", label: "Active Today", icon: "person.2.fill", color: .orange)
        }
    }

    private func overviewCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAILY RECORDINGS")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(0.8)

            VStack(spacing: 8) {
                let maxVal = weeklyData.map(\.1).max() ?? 1
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklyData, id: \.0) { day, count in
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.7))
                                .frame(height: CGFloat(count) / CGFloat(maxVal) * 100)

                            Text(day)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 140)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Language Distribution

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LANGUAGE DISTRIBUTION")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(0.8)

            VStack(spacing: 8) {
                ForEach(languageData, id: \.0) { language, percentage in
                    HStack(spacing: 12) {
                        Text(language)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .frame(width: 70, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: language))
                                .frame(width: geo.size.width * percentage)
                        }
                        .frame(height: 20)

                        Text("\(Int(percentage * 100))%")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func barColor(for language: String) -> Color {
        switch language {
        case "English": return .blue
        case "Spanish": return .orange
        case "Japanese": return .red
        default: return .gray
        }
    }

    // MARK: - Top Users

    private var topUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP USERS THIS WEEK")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(0.8)

            VStack(spacing: 0) {
                let topUsers: [(String, Int)] = [
                    ("Maria Garcia", 12),
                    ("Yuki Tanaka", 10),
                    ("Ahmed Khan", 8),
                    ("Sofia Rodriguez", 7),
                    ("Wei Liu", 5),
                ]

                ForEach(Array(topUsers.enumerated()), id: \.offset) { index, user in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(index < 3 ? .blue : .secondary)
                            .frame(width: 28)

                        ZStack {
                            Circle()
                                .fill(Color.indigo.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Text(String(user.0.prefix(1)))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundColor(.indigo)
                        }

                        Text(user.0)
                            .font(.system(.subheadline, design: .rounded))

                        Spacer()

                        Text("\(user.1) recordings")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < topUsers.count - 1 {
                        Divider().padding(.leading, 80)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    NavigationView { UsageStatsView() }
}
