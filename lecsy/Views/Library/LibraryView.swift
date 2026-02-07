//
//  LibraryView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import UIKit

struct LibraryView: View {
    @StateObject private var store = LectureStore.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var authService = AuthService.shared
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isSyncingTitles = false
    @State private var showSyncError = false
    @State private var syncErrorMessage = ""
    
    var filteredLectures: [Lecture] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lectures: [Lecture]
        if trimmedQuery.isEmpty {
            lectures = store.lectures
        } else {
            lectures = store.searchLectures(query: trimmedQuery)
        }
        // 新しいものが上に来るように日付で降順ソート
        return lectures.sorted { $0.createdAt > $1.createdAt }
    }
    
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索結果の件数表示（Listの外に配置）
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
                
                // メインコンテンツ
                if filteredLectures.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Lectures")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text(store.lectures.isEmpty ? "Record your first lecture from the Record tab" : "No lectures match your search")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredLectures) { lecture in
                            NavigationLink(destination: LectureDetailView(lecture: lecture)) {
                                LectureRow(lecture: lecture, searchQuery: isSearching ? searchText : "")
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.deleteLecture(filteredLectures[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                prompt: "Search lectures"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await syncTitlesFromWeb()
                        }
                    }) {
                        if isSyncingTitles {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isSyncingTitles || !authService.isAuthenticated)
                }
            }
            .alert("Sync Error", isPresented: $showSyncError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncErrorMessage)
            }
        }
    }
    
    /// Webからタイトルを同期
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
            print("✅ LibraryView: Title sync successful")
        } catch {
            syncErrorMessage = error.localizedDescription
            showSyncError = true
            print("❌ LibraryView: Title sync failed - \(error.localizedDescription)")
        }
    }
}

struct LectureRow: View {
    let lecture: Lecture
    let searchQuery: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タイトル（検索クエリがあればハイライト）
            if !searchQuery.isEmpty {
                HighlightedText(text: lecture.displayTitle, query: searchQuery)
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text(lecture.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            HStack {
                Text(lecture.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(lecture.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 文字起こしテキストのプレビュー（検索クエリがあればハイライト）
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
            
            // Transcription status with progress indicator
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
        case .notStarted:
            return .gray
        case .downloading, .processing:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

/// 検索クエリをハイライト表示するView
struct HighlightedText: View {
    let text: String
    let query: String
    
    var body: some View {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return AnyView(Text(text))
        }
        
        // NSAttributedStringを使ってハイライトを実装
        let nsString = text as NSString
        let attributedString = NSMutableAttributedString(string: text)
        
        // すべてのマッチ箇所をハイライト（大文字小文字を区別しない）
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
        
        // NSAttributedStringをAttributedStringに変換
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
