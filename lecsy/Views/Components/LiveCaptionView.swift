//
//  LiveCaptionView.swift
//  lecsy
//
//  Apple Music 時間同期歌詞のデザイン言語を live transcription に移植。
//
//  原則:
//   1. 超大型 rounded semibold タイポ → 一文字一文字が "歌詞" のように見える
//   2. アクティブ行（最新 final または interim）が画面を支配、過去行は opacity decay
//   3. 上部に fade グラデーションマスク → 古い行がふわっと消える
//   4. interim は word-by-word で fade-in (カラオケ風、FlowLayout で折返し)
//   5. chrome をほぼ排除、`.ultraThinMaterial` の背景のみ
//   6. spring auto-scroll で Apple Music 同等のヌルヌル感
//

import SwiftUI
import UIKit

struct LiveCaptionView: View {

    @ObservedObject var coordinator: TranscriptionCoordinator
    @State private var pulse: Bool = false
    @State private var cursorOn: Bool = true
    @State private var lastHapticSegmentCount: Int = 0

    private let lightHaptic: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
    }()

    private enum Phase { case connecting, listening, live }
    private var phase: Phase {
        if coordinator.isPreparing && !coordinator.isLiveActive { return .connecting }
        return coordinator.liveSegments.isEmpty && coordinator.interimText.isEmpty
            ? .listening
            : .live
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            )
            .overlay(alignment: .topLeading) {
                statusPill
                    .padding(.top, 14)
                    .padding(.leading, 16)
            }
            .onAppear {
                pulse = true
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    cursorOn.toggle()
                }
                lastHapticSegmentCount = coordinator.liveSegments.count
            }
            .onChange(of: coordinator.liveSegments.count) { _, newCount in
                if newCount > lastHapticSegmentCount, phase == .live {
                    lightHaptic.impactOccurred(intensity: 0.45)
                    lightHaptic.prepare()
                }
                lastHapticSegmentCount = newCount
            }
    }

    // MARK: - Status pill (minimal, floats in corner)

    private var statusPill: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.25))
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulse ? 1.3 : 0.7)
                    .opacity(pulse ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                Circle()
                    .fill(statusTint)
                    .frame(width: 6, height: 6)
            }
            Text(statusLabel)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(statusTint)
                .tracking(1.5)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(statusTint.opacity(0.12)))
    }

    private var statusLabel: String { phase == .connecting ? "CONNECTING" : "LIVE" }
    private var statusTint: Color { phase == .connecting ? .blue : .red }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .connecting: connectingState
        case .listening:  listeningState
        case .live:       lyricsScroll
        }
    }

    // MARK: - Empty states

    private var connectingState: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                        .frame(width: CGFloat(26 + i * 20), height: CGFloat(26 + i * 20))
                        .scaleEffect(pulse ? 1.1 : 0.7)
                        .opacity(pulse ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.25),
                            value: pulse
                        )
                }
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text("Preparing captions…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Connecting to the transcription service")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.vertical, 28)
    }

    private var listeningState: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 4, height: barHeight(for: i))
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                            value: pulse
                        )
                }
            }
            .frame(height: 36)

            Text("Listening…")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.vertical, 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [12, 24, 36, 24, 12]
        return pulse ? heights[index] : 8
    }

    // MARK: - Lyrics-style scroll

    private var lyricsScroll: some View {
        let all = coordinator.liveSegments
        let hasInterim = !coordinator.interimText.isEmpty
        let total = all.count
        let lastFinalIndex = total - 1

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // 上部の status pill と重ならない余白
                    Color.clear.frame(height: 12)

                    ForEach(Array(all.enumerated()), id: \.element.id) { pair in
                        let (idx, seg) = pair
                        let isActive = (idx == lastFinalIndex) && !hasInterim
                        lyricLine(
                            text: seg.text,
                            depth: total - 1 - idx,
                            isActive: isActive
                        )
                        .id(seg.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 20)),
                            removal: .opacity
                        ))
                    }

                    if hasInterim {
                        InterimLyricLine(
                            text: coordinator.interimText,
                            cursorOn: cursorOn
                        )
                        .id("interim")
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 420)
            // 上部 fade グラデ: 古い行が消えていくように見せる (Apple Music 歌詞)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.4), location: 0.04),
                        .init(color: .black, location: 0.18),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: coordinator.liveSegments.count) { _, _ in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    if hasInterim {
                        proxy.scrollTo("interim", anchor: .bottom)
                    } else if let last = coordinator.liveSegments.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: coordinator.interimText) { _, newValue in
                guard !newValue.isEmpty else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo("interim", anchor: .bottom)
                }
            }
        }
    }

    /// Apple Music 歌詞風の1行。depth が大きいほど小さく / 薄く。
    @ViewBuilder
    private func lyricLine(text: String, depth: Int, isActive: Bool) -> some View {
        let (size, weight, opacity): (CGFloat, Font.Weight, Double) = {
            if isActive { return (28, .semibold, 1.0) }
            switch depth {
            case 0, 1: return (19, .regular, 0.55)
            case 2:    return (16, .regular, 0.40)
            default:   return (14, .regular, 0.28)
            }
        }()

        Text(text)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(Color.primary.opacity(opacity))
            .lineSpacing(size * 0.22)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Interim (karaoke-style word reveal)

/// 喋られている途中のテキストを単語ごとに fade-in で出す。
/// Deepgram の interim は cumulative なので、単語数が増えるたびに
/// 新しく追加された単語だけがトランジションで入ってくる。
private struct InterimLyricLine: View {
    let text: String
    let cursorOn: Bool

    var body: some View {
        let words = text
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        FlowLayout(hSpacing: 7, vSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)).animation(.easeOut(duration: 0.28)),
                        removal: .opacity.animation(.easeIn(duration: 0.12))
                    ))
            }
            // 末尾の blinking cursor
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 2.5, height: 28)
                .opacity(cursorOn ? 1.0 : 0.0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: words.count)
    }
}

// MARK: - FlowLayout

/// SwiftUI 標準には無い "折返しする HStack"。
/// 単語単位で Text を並べたい interim 表示に使う。
private struct FlowLayout: Layout {
    var hSpacing: CGFloat = 6
    var vSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, maxWidth: maxWidth).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = layout(sizes: sizes, maxWidth: maxWidth)
        for i in subviews.indices {
            let p = result.offsets[i]
            subviews[i].place(
                at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y),
                proposal: ProposedViewSize(sizes[i])
            )
        }
    }

    private func layout(sizes: [CGSize], maxWidth: CGFloat) -> (size: CGSize, offsets: [CGPoint]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var offsets: [CGPoint] = []
        var totalMaxX: CGFloat = 0

        for size in sizes {
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + vSpacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            x += size.width + hSpacing
            lineHeight = max(lineHeight, size.height)
            totalMaxX = max(totalMaxX, x - hSpacing)
        }

        return (CGSize(width: max(totalMaxX, 0), height: y + lineHeight), offsets)
    }
}
