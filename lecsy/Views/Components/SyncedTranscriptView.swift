//
//  SyncedTranscriptView.swift
//  lecsy
//
//  Created on 2026/02/22.
//

import SwiftUI

struct SyncedTranscriptView: View {
    let segments: [TranscriptionResult.TranscriptionSegment]
    let currentTime: TimeInterval
    let isPlaying: Bool
    let bookmarks: [LectureBookmark]
    let onSegmentTap: (TimeInterval) -> Void

    @State private var autoScrollEnabled = true

    init(
        segments: [TranscriptionResult.TranscriptionSegment],
        currentTime: TimeInterval,
        isPlaying: Bool,
        bookmarks: [LectureBookmark] = [],
        onSegmentTap: @escaping (TimeInterval) -> Void
    ) {
        self.segments = segments
        self.currentTime = currentTime
        self.isPlaying = isPlaying
        self.bookmarks = bookmarks
        self.onSegmentTap = onSegmentTap
    }

    private func hasBookmark(for segment: TranscriptionResult.TranscriptionSegment) -> Bool {
        bookmarks.contains { $0.timestamp >= segment.startTime && $0.timestamp < segment.endTime }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    // PERF: Iterate indices directly instead of
                    // `Array(segments.enumerated())` — the latter allocates
                    // a new array on every body re-render (once per audio
                    // player tick during playback), which for long lectures
                    // meant thousands of allocations per second.
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        let isActive = isPlaying && currentTime >= segment.startTime && currentTime < segment.endTime
                        let isBookmarked = hasBookmark(for: segment)

                        Button {
                            onSegmentTap(segment.startTime)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                if isBookmarked {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                        .frame(width: 40, alignment: .trailing)
                                } else {
                                    Text(formatTimestamp(segment.startTime))
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .frame(width: 40, alignment: .trailing)
                                }

                                Text(segment.cleanText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isActive ? Color.blue.opacity(0.15) : isBookmarked ? Color.orange.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: currentTime) { _, newTime in
                guard autoScrollEnabled, isPlaying else { return }
                if let activeIndex = binarySearchSegment(for: newTime) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(activeIndex, anchor: .center)
                    }
                }
            }
        }
    }

    /// Binary search for the segment containing the given time — O(log n) instead of O(n)
    private func binarySearchSegment(for time: TimeInterval) -> Int? {
        var low = 0
        var high = segments.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let seg = segments[mid]
            if time < seg.startTime {
                high = mid - 1
            } else if time >= seg.endTime {
                low = mid + 1
            } else {
                return mid
            }
        }
        return nil
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
