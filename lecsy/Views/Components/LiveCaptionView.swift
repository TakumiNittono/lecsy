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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                statusPill
                Spacer()
                if phase == .live {
                    HStack(spacing: 4) {
                        Image(systemName: "globe").font(.caption2)
                        Text("Auto").font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            content
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        )
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

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.3 : 0.7)
                    .opacity(pulse ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)
            }
            Text(statusLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(statusTint)
                .tracking(1.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
                            insertion: .opacity.combined(with: .offset(y: 12))
                                .animation(.easeOut(duration: 0.45)),
                            removal: .opacity.animation(.easeIn(duration: 0.2))
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
                .padding(.top, 6)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 高さを固定帯にする。minHeight を入れないと content が小さい時に
            // カードが shrink し、latest が常に「カード最下段」に貼り付いて見える。
            .frame(minHeight: 300, maxHeight: 380)
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
                // アクティブ行を視覚中心から少し上 (y=0.38) に固定する。
                // 下寄せだと「枠の最下段」に字幕が貼り付いて視線が下がる。
                // スプリングを緩め (response 0.75) にして "音楽の小節が切り替わる"
                // くらいのテンポに。キビキビし過ぎると慌ただしく感じる。
                withAnimation(.spring(response: 0.75, dampingFraction: 0.88)) {
                    if hasInterim {
                        proxy.scrollTo("interim", anchor: UnitPoint(x: 0.5, y: 0.38))
                    } else if let last = coordinator.liveSegments.last {
                        proxy.scrollTo(last.id, anchor: UnitPoint(x: 0.5, y: 0.38))
                    }
                }
            }
            .onChange(of: coordinator.interimText) { _, newValue in
                guard !newValue.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    proxy.scrollTo("interim", anchor: UnitPoint(x: 0.5, y: 0.38))
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
            // 過去行が "格下げ" される時 (latest → recent → older) にフォントサイズ・
            // 色が跳ねず、やわらかく縮んでいくようにする。
            .animation(.easeInOut(duration: 0.45), value: isActive)
            .animation(.easeInOut(duration: 0.45), value: depth)
    }
}

// MARK: - Interim (smooth cross-fade update)

/// 喋られている途中のテキスト。Deepgram は interim を高頻度で投げてきて
/// (100-200ms 間隔)、その都度 ForEach で単語を keyed にすると
/// SwiftUI の再計算コストでチカチカして見える。
/// 単一 Text + `.contentTransition(.opacity)` で文字列全体を滑らかに
/// クロスフェードさせる方が Apple Music 歌詞の "テキストがにじみ出る"
/// 感覚に近い。
private struct InterimLyricLine: View {
    let text: String
    let cursorOn: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(text)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.22), value: text)

            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 2.5, height: 28)
                .opacity(cursorOn ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
