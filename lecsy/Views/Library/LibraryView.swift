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
    @StateObject private var streakService = StudyStreakService.shared
    @StateObject private var orgService = OrganizationService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var isSearchActive = false
    @State private var selectedCourse: String? = nil
    @State private var showDeleteConfirmation = false
    @State private var lectureToDelete: Lecture?
    @State private var showUndoBanner = false
    @State private var recentlyDeletedLecture: Lecture?
    @State private var recentlyDeletedAudioURL: URL?
    @State private var undoTimer: Task<Void, Never>?
    @AppStorage("lecsy.sortOption") private var sortOption: String = LectureSortOption.dateNewest.rawValue


    private var currentSort: LectureSortOption {
        LectureSortOption(rawValue: sortOption) ?? .dateNewest
    }

    var filteredLectures: [Lecture] {
        let trimmedQuery = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var lectures: [Lecture]
        if trimmedQuery.isEmpty {
            lectures = store.lectures
        } else {
            lectures = store.searchLectures(query: trimmedQuery)
        }
        if let course = selectedCourse {
            lectures = lectures.filter { $0.courseName == course }
        }

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
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

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
        !debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // First-launch AI model warning
                if !transcriptionService.isModelLoaded && !UserDefaults.standard.bool(forKey: "lecsy.hasCompletedFirstModelLoad") {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("First-time setup: ~1 minute")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        Text("Only the first launch takes time. Next time it's instant.")
                            .font(.system(.caption2, design: .rounded))
                            .multilineTextAlignment(.center)
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.red)
                            Text("Preparing AI model...")
                                .font(.system(.caption2, design: .rounded))
                        }
                        .padding(.top, 2)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Weekly stats card
                if !store.lectures.isEmpty && !isSearching {
                    weeklyStatsCard
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                // Organization shared recordings hint
                if orgService.isInOrganization && !isSearching {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        Text("\(orgService.currentOrganization?.name ?? "") recordings are synced")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Sort & Course filter bar
                HStack(spacing: 12) {
                    // Course filter pills
                    if !store.allCourseNames().isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                filterPill(title: "All", isSelected: selectedCourse == nil) {
                                    selectedCourse = nil
                                }

                                ForEach(store.allCourseNames(), id: \.self) { course in
                                    filterPill(title: course, isSelected: selectedCourse == course) {
                                        selectedCourse = selectedCourse == course ? nil : course
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Sort button
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
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Sort lectures")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Search result count
                if isSearching && !filteredLectures.isEmpty {
                    HStack {
                        Text("\(filteredLectures.count) result\(filteredLectures.count == 1 ? "" : "s")")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Main content
                if filteredLectures.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedLectures, id: \.0) { sectionTitle, lectures in
                            Section {
                                ForEach(lectures) { lecture in
                                    NavigationLink(destination: LectureDetailView(lecture: lecture)) {
                                        LectureRow(lecture: lecture, searchQuery: isSearching ? debouncedSearchText : "")
                                    }
                                }
                                .onDelete { indexSet in
                                    if let index = indexSet.first {
                                        lectureToDelete = lectures[index]
                                        showDeleteConfirmation = true
                                    }
                                }
                            } header: {
                                Text(sectionTitle)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .kerning(0.5)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        store.loadLectures()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Library")
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                prompt: "Search lectures"
            )
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = newValue
                }
            }
        }
        .alert("Delete Lecture?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let lecture = lectureToDelete {
                    deleteLectureWithUndo(lecture)
                }
                lectureToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                lectureToDelete = nil
            }
        } message: {
            if let lecture = lectureToDelete {
                Text("Delete \"\(lecture.displayTitle)\"? You can undo this for a few seconds.")
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoBanner {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Lecture deleted")
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") {
                        undoDelete()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showUndoBanner)
        .navigationViewStyle(.stack)
    }

    // MARK: - Filter Pill

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Stats Card

    private var weeklyStatsCard: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(streakService.currentStreak)",
                label: "STREAK",
                icon: "flame.fill",
                color: streakService.currentStreak > 0 ? .orange : .secondary
            )

            statDivider

            statItem(
                value: "\(streakService.thisWeekLectures)",
                label: "THIS WEEK",
                icon: "calendar",
                color: .blue
            )

            statDivider

            statItem(
                value: "\(store.lectures.count)",
                label: "TOTAL",
                icon: "doc.text.fill",
                color: .green
            )
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(color == .secondary ? .secondary : .primary)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1, height: 28)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            if store.lectures.isEmpty {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 96, height: 96)
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.6))
                }

                Text("Record your first lecture")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("Tap the Record tab to capture lectures\nwith AI transcription.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if isSearching {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.06))
                        .frame(width: 96, height: 96)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                Text("No results")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("No lectures match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.06))
                        .frame(width: 96, height: 96)
                    Image(systemName: "folder")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                Text("No lectures in this course")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)

                Button {
                    selectedCourse = nil
                } label: {
                    Text("Show all lectures")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete with Undo

    private func deleteLectureWithUndo(_ lecture: Lecture) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        recentlyDeletedLecture = lecture
        recentlyDeletedAudioURL = lecture.audioPath

        store.lectures.removeAll { $0.id == lecture.id }
        store.saveLectures()

        showUndoBanner = true

        undoTimer?.cancel()
        undoTimer = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            finalizeDelete()
        }
    }

    private func undoDelete() {
        undoTimer?.cancel()
        undoTimer = nil

        guard let lecture = recentlyDeletedLecture else { return }

        store.addLecture(lecture)

        recentlyDeletedLecture = nil
        recentlyDeletedAudioURL = nil
        showUndoBanner = false

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func finalizeDelete() {
        if let audioURL = recentlyDeletedAudioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        recentlyDeletedLecture = nil
        recentlyDeletedAudioURL = nil
        showUndoBanner = false
    }

}

// MARK: - Lecture Row

struct LectureRow: View {
    let lecture: Lecture
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            if !searchQuery.isEmpty {
                HighlightedText(text: lecture.displayTitle, query: searchQuery)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            } else {
                Text(lecture.displayTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            }

            // Duration + Course + Date
            HStack(spacing: 8) {
                // Duration pill
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(lecture.formattedDuration)
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundColor(.secondary)

                if let course = lecture.courseName {
                    Text(course)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(lecture.createdAt, style: .date)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            // Transcript preview
            if let transcriptText = lecture.transcriptText, !transcriptText.isEmpty {
                let cleaned = TranscriptionResult.TranscriptionSegment.stripWhisperTokens(transcriptText)
                let preview = String(cleaned.prefix(100)) + (cleaned.count > 100 ? "..." : "")
                if !searchQuery.isEmpty {
                    HighlightedText(text: preview, query: searchQuery)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                } else {
                    Text(preview)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                }
            }

            // Status
            HStack(spacing: 5) {
                if lecture.transcriptStatus == .processing || lecture.transcriptStatus == .downloading {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text(lecture.transcriptStatus == .downloading ? "Downloading..." : "Transcribing...")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.orange)
                } else if lecture.transcriptStatus == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.7))
                    Text("Completed")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.green.opacity(0.7))
                } else if lecture.transcriptStatus == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                    Text("Failed")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.red.opacity(0.7))
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Not transcribed")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 4)
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
