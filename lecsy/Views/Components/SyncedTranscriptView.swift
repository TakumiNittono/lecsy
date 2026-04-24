//
//  SyncedTranscriptView.swift
//  lecsy
//
//  Created on 2026/02/22.
//

import SwiftUI
import UIKit

struct SyncedTranscriptView: View {
    let segments: [TranscriptionResult.TranscriptionSegment]
    let currentTime: TimeInterval
    let isPlaying: Bool
    let bookmarks: [LectureBookmark]
    let onSegmentTap: (TimeInterval) -> Void

    @State private var autoScrollEnabled = true
    // Segments to actually render. `segments` (input) may contain super-long
    // Deepgram utterances where the speaker never paused >0.8s — resulting in
    // a single block that fills the screen. We split those at sentence
    // boundaries at display time, so old lectures benefit without a migration
    // and the stored transcript format stays untouched.
    @State private var displaySegments: [TranscriptionResult.TranscriptionSegment] = []

    /// Split thresholds. Segments longer than either axis get broken into
    /// ~targetChunkChars-sized chunks at sentence boundaries.
    private static let maxSegmentDuration: TimeInterval = 12
    private static let maxSegmentChars: Int = 180
    private static let targetChunkChars: Int = 120

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
                    ForEach(displaySegments.indices, id: \.self) { index in
                        let segment = displaySegments[index]
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
                        .contextMenu {
                            Button {
                                copySegment(segment, withTimestamp: false)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            Button {
                                copySegment(segment, withTimestamp: true)
                            } label: {
                                Label("Copy with Timestamp", systemImage: "clock")
                            }
                        }
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
            .onAppear {
                displaySegments = Self.splitLongSegments(segments)
            }
            .onChange(of: segments) { _, newSegments in
                displaySegments = Self.splitLongSegments(newSegments)
            }
        }
    }

    /// Binary search for the segment containing the given time — O(log n) instead of O(n)
    private func binarySearchSegment(for time: TimeInterval) -> Int? {
        var low = 0
        var high = displaySegments.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let seg = displaySegments[mid]
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

    // MARK: - Long-segment splitter

    /// Break up any segment whose duration or length exceeds the thresholds
    /// by grouping sentences up to ~targetChunkChars. Timestamps inside the
    /// original segment are re-allocated proportionally to character count,
    /// so tap-to-seek still lands inside the right audio region.
    ///
    /// Deepgram's `utterances` keeps a single utterance going until the
    /// speaker pauses for >0.8s — in a lecture that regularly produces a
    /// one-minute block with no line break. WhisperKit occasionally does
    /// the same on long runs. We fix both at the display layer.
    static func splitLongSegments(
        _ segments: [TranscriptionResult.TranscriptionSegment]
    ) -> [TranscriptionResult.TranscriptionSegment] {
        var out: [TranscriptionResult.TranscriptionSegment] = []
        out.reserveCapacity(segments.count)
        for seg in segments {
            let text = seg.cleanText
            let duration = max(0, seg.endTime - seg.startTime)
            let tooLong = duration > maxSegmentDuration || text.count > maxSegmentChars
            if !tooLong || text.isEmpty {
                out.append(seg)
                continue
            }
            let chunks = splitTextBySentence(text, target: targetChunkChars)
            if chunks.count <= 1 {
                out.append(seg)
                continue
            }
            let totalChars = chunks.reduce(0) { $0 + $1.count }
            guard totalChars > 0 else {
                out.append(seg)
                continue
            }
            var cursor = seg.startTime
            for (i, chunk) in chunks.enumerated() {
                let chunkDur = duration * Double(chunk.count) / Double(totalChars)
                let chunkEnd = (i == chunks.count - 1) ? seg.endTime : cursor + chunkDur
                out.append(.init(startTime: cursor, endTime: chunkEnd, text: chunk))
                cursor = chunkEnd
            }
        }
        return out
    }

    /// Split text at sentence enders (. ! ? 。 ！ ？ newline), then pack the
    /// resulting sentences into ~target-char groups so we don't produce tons
    /// of 2-word segments. Falls back to the original text if no boundaries
    /// are found.
    private static func splitTextBySentence(_ text: String, target: Int) -> [String] {
        let ns = text as NSString
        var sentences: [String] = []
        var cursor = 0
        if let regex = try? NSRegularExpression(
            pattern: "[^.!?。！？\\n]*[.!?。！？\\n]+\\s*",
            options: []
        ) {
            regex.enumerateMatches(
                in: text,
                options: [],
                range: NSRange(location: 0, length: ns.length)
            ) { match, _, _ in
                guard let match = match else { return }
                let piece = ns.substring(with: match.range)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { sentences.append(piece) }
                cursor = match.range.location + match.range.length
            }
        }
        if cursor < ns.length {
            let tail = ns.substring(from: cursor)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { sentences.append(tail) }
        }
        if sentences.isEmpty { return [text] }

        // Pack sentences into chunks up to ~target chars. Allow a small
        // overshoot so we don't split a single long sentence that fits just
        // above the target.
        var chunks: [String] = []
        var buf = ""
        let overshoot = target + 40
        for s in sentences {
            if buf.isEmpty {
                buf = s
            } else if buf.count + 1 + s.count <= overshoot {
                buf += " " + s
            } else {
                chunks.append(buf)
                buf = s
            }
        }
        if !buf.isEmpty { chunks.append(buf) }
        return chunks
    }

    private func copySegment(_ segment: TranscriptionResult.TranscriptionSegment, withTimestamp: Bool) {
        let text = withTimestamp
            ? "[\(formatTimestamp(segment.startTime))] \(segment.cleanText)"
            : segment.cleanText
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
