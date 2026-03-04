//
//  LibraryView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import UIKit

enum LectureSortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case durationLongest = "Longest"
    case durationShortest = "Shortest"
    case titleAZ = "Title A-Z"
}

struct LibraryView: View {
    @StateObject private var store = LectureStore.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var authService = AuthService.shared
    @StateObject private var streakService = StudyStreakService.shared
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isSyncingTitles = false
    @State private var showSyncError = false
    @State private var syncErrorMessage = ""
    @State private var selectedCourse: String? = nil
    @AppStorage("lecsy.sortOption") private var sortOption: String = LectureSortOption.dateNewest.rawValue


    private var currentSort: LectureSortOption {
        LectureSortOption(rawValue: sortOption) ?? .dateNewest
    }

    var filteredLectures: [Lecture] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var lectures: [Lecture]
        if trimmedQuery.isEmpty {
            lectures = store.lectures
        } else {
            lectures = store.searchLectures(query: trimmedQuery)
        }
        if let course = selectedCourse {
            lectures = lectures.filter { $0.courseName == course }
        }

        // Apply sort
        switch currentSort {
        case .dateNewest:
            return lectures.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return lectures.sorted { $0.createdAt < $1.createdAt }
        case .durationLongest:
            return lectures.sorted { $0.duration > $1.duration }
        case .durationShortest:
            return lectures.sorted { $0.duration < $1.duration }
        case .titleAZ:
            return lectures.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        }
    }

    var groupedLectures: [(String, [Lecture])] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!

        var groups: [String: [Lecture]] = [:]
        let order = ["Today", "Yesterday", "This Week", "Earlier"]

        for lecture in filteredLectures {
            let key: String
            if lecture.createdAt >= startOfToday {
                key = "Today"
            } else if lecture.createdAt >= startOfYesterday {
                key = "Yesterday"
            } else if lecture.createdAt >= startOfWeek {
                key = "This Week"
            } else {
                key = "Earlier"
            }
            groups[key, default: []].append(lecture)
        }

        return order.compactMap { key in
            guard let lectures = groups[key], !lectures.isEmpty else { return nil }
            return (key, lectures)
        }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort & Sync bar
                HStack {
                    Menu {
                        ForEach(LectureSortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option.rawValue
                            } label: {
                                if currentSort == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Button {
                        Task { await syncTitlesFromWeb() }
                    } label: {
                        if isSyncingTitles {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(authService.isAuthenticated ? .accentColor : .secondary)
                        }
                    }
                    .disabled(isSyncingTitles || !authService.isAuthenticated)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))

                // Weekly stats card
                if !store.lectures.isEmpty && !isSearching {
                    weeklyStatsCard
                }

                // Course filter pills
                if !store.allCourseNames().isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                selectedCourse = nil
                            } label: {
                                Text("All")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCourse == nil ? Color.accentColor : Color.secondary.opacity(0.08))
                                    .foregroundColor(selectedCourse == nil ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            ForEach(store.allCourseNames(), id: \.self) { course in
                                Button {
                                    selectedCourse = selectedCourse == course ? nil : course
                                } label: {
                                    Text(course)
                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedCourse == course ? Color.accentColor : Color.secondary.opacity(0.08))
                                        .foregroundColor(selectedCourse == course ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))
                }

                // Search result count
                if isSearching && !filteredLectures.isEmpty {
                    HStack {
                        Text("Found \(filteredLectures.count) lectures")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
                }

                // Main content
                if filteredLectures.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedLectures, id: \.0) { sectionTitle, lectures in
                            Section(sectionTitle) {
                                ForEach(lectures) { lecture in
                                    NavigationLink(destination: LectureDetailView(lecture: lecture)) {
                                        LectureRow(lecture: lecture, searchQuery: isSearching ? searchText : "")
                                    }
                                }
                                .onDelete { indexSet in
                                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                    for index in indexSet {
                                        store.deleteLecture(lectures[index])
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await syncTitlesFromWeb()
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                prompt: "Search lectures"
            )
            .alert("Sync Error", isPresented: $showSyncError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncErrorMessage)
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Weekly Stats Card

    private var weeklyStatsCard: some View {
        HStack(spacing: 0) {
            // Streak
            VStack(spacing: 4) {
                Text("\(streakService.currentStreak)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(streakService.currentStreak > 0 ? .orange : .secondary)
                Text("day streak")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 32)

            // This week lectures
            VStack(spacing: 4) {
                Text("\(streakService.thisWeekLectures)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("this week")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 32)

            // Total lectures
            VStack(spacing: 4) {
                Text("\(store.lectures.count)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("total")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            if store.lectures.isEmpty {
                // No lectures at all
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(.blue.opacity(0.7))
                Text("Record your first lecture")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Tap the Record tab to start capturing lectures with AI transcription.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if isSearching {
                // No search results
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundColor(.gray.opacity(0.6))
                Text("No results")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("No lectures match \"\(searchText)\". Try a different search term.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                // No lectures in selected course
                Image(systemName: "folder")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("No lectures in this course")
                    .font(.title3.bold())
                    .foregroundColor(.gray)

                Button {
                    selectedCourse = nil
                } label: {
                    Text("Show all lectures")
                        .font(.subheadline)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sync

    @MainActor
    private func syncTitlesFromWeb() async {
        guard await authService.isSessionValid else {
            syncErrorMessage = "Not authenticated"
            showSyncError = true
            return
        }

        isSyncingTitles = true
        defer {
            isSyncingTitles = false
        }

        do {
            try await syncService.syncTitlesFromWeb()
        } catch {
            syncErrorMessage = error.localizedDescription
            showSyncError = true
        }
    }
}

struct LectureRow: View {
    let lecture: Lecture
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !searchQuery.isEmpty {
                HighlightedText(text: lecture.displayTitle, query: searchQuery)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            } else {
                Text(lecture.displayTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            }

            HStack {
                Text(lecture.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                if let course = lecture.courseName {
                    Text(course)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(4)
                }

                Spacer()

                Text(lecture.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let transcriptText = lecture.transcriptText, !transcriptText.isEmpty {
                let preview = String(transcriptText.prefix(100)) + (transcriptText.count > 100 ? "..." : "")
                if !searchQuery.isEmpty {
                    HighlightedText(text: preview, query: searchQuery)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 6) {
                if lecture.transcriptStatus == .processing || lecture.transcriptStatus == .downloading {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(lecture.transcriptStatus == .downloading ? "Downloading Model..." : "Transcribing...")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(lecture.transcriptStatus.displayName)
                        .font(.caption2)
                        .foregroundColor(statusColor(for: lecture.transcriptStatus))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: TranscriptionStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .downloading, .processing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

/// Highlight search query in text
struct HighlightedText: View {
    let text: String
    let query: String

    var body: some View {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return AnyView(Text(text))
        }

        let nsString = text as NSString
        let attributedString = NSMutableAttributedString(string: text)

        var searchRange = NSRange(location: 0, length: nsString.length)
        while searchRange.location < nsString.length {
            let foundRange = nsString.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
            if foundRange.location != NSNotFound {
                attributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: foundRange)
                searchRange = NSRange(location: foundRange.location + foundRange.length, length: nsString.length - (foundRange.location + foundRange.length))
            } else {
                break
            }
        }

        if let swiftAttributedString = try? AttributedString(attributedString, including: \.uiKit) {
            return AnyView(Text(swiftAttributedString))
        } else {
            return AnyView(Text(text))
        }
    }
}

#Preview {
    LibraryView()
}
