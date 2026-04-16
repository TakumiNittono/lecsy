//
//  LiveCaptionView.swift
//  lecsy
//
//  リアルタイム字幕パネル。
//
//  デザインの指針 (Apple Live Captions / Otter.ai / Rev.ai の研究より):
//   1. 最新行を圧倒的に支配的にする (teleprompter 原則)
//   2. interim と final の視覚差を最小化してシームレスに感じさせる
//      (同じ font size、weight とカーソルだけで "確定度" を表現)
//   3. 新しい final には軽い触覚 (Apple の音声入力と同じ作法)
//   4. 古い行は opacity で decay、ユーザーが遡れるよう履歴は残す
//   5. Chrome は最小限。スクロールインジケータもカウントも出さない
//

import SwiftUI
import UIKit

struct LiveCaptionView: View {

    @ObservedObject var coordinator: TranscriptionCoordinator
    @State private var pulse: Bool = false
    @State private var cursorOn: Bool = true
    @State private var lastHapticSegmentCount: Int = 0

    /// 触覚フィードバック用の generator は事前 prepare で応答速度を稼ぐ
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
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().opacity(0.22)

            content
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color(.secondarySystemBackground).opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                cursorOn.toggle()
            }
            lastHapticSegmentCount = coordinator.liveSegments.count
        }
        // 新しい final segment が入ったら軽く触覚フィードバック。
        // 無音レーザーのように途切れなく字幕が流れてもうるさくならない強度。
        .onChange(of: coordinator.liveSegments.count) { _, newCount in
            if newCount > lastHapticSegmentCount, phase == .live {
                lightHaptic.impactOccurred(intensity: 0.45)
                lightHaptic.prepare()
            }
            lastHapticSegmentCount = newCount
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            statusPill

            Spacer()

            if let err = coordinator.liveError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 180, alignment: .trailing)
            } else if phase == .live {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text("Auto")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    /// カプセル型のステータスピル。count バッジなど情報ノイズは入れない。
    private var statusPill: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.25 : 0.8)
                    .opacity(pulse ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
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
        .background(
            Capsule(style: .continuous)
                .fill(statusTint.opacity(0.12))
        )
    }

    private var statusLabel: String {
        phase == .connecting ? "CONNECTING" : "LIVE"
    }

    private var statusTint: Color {
        phase == .connecting ? .blue : .red
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .connecting:
            connectingState
        case .listening:
            listeningState
        case .live:
            captionScroll
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Connecting to the transcription service")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 20)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [12, 24, 36, 24, 12]
        return pulse ? heights[index] : 8
    }

    // MARK: - Caption scroll

    private var captionScroll: some View {
        let all = coordinator.liveSegments
        let total = all.count
        let lastFinalIndex = total - 1
        let hasInterim = !coordinator.interimText.isEmpty

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(all.enumerated()), id: \.element.id) { pair in
                        let (idx, seg) = pair
                        let isLatestFinal = (idx == lastFinalIndex) && !hasInterim
                        captionLine(
                            text: seg.text,
                            emphasis: emphasis(for: idx, total: total, isLatestFinal: isLatestFinal)
                        )
                        .id(seg.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .identity
                        ))
                    }

                    if hasInterim {
                        interimLine
                            .id("interim")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 380)
            .onChange(of: coordinator.liveSegments.count) { _, _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if let last = coordinator.liveSegments.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: coordinator.interimText) { _, newValue in
                guard !newValue.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("interim", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Caption line styling

    enum Emphasis {
        case latest    // 最新確定: 大きく、白強
        case recent    // 直近2行: 中、わずかに薄い
        case older     // それ以前: 小さく、淡く
    }

    private func emphasis(for idx: Int, total: Int, isLatestFinal: Bool) -> Emphasis {
        if isLatestFinal { return .latest }
        let distanceFromEnd = (total - 1) - idx
        if distanceFromEnd <= 2 { return .recent }
        return .older
    }

    @ViewBuilder
    private func captionLine(text: String, emphasis: Emphasis) -> some View {
        switch emphasis {
        case .latest:
            // 最新は 22pt semibold、読者の視線の終着点
            Text(text)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        case .recent:
            Text(text)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.72))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        case .older:
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.45))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Interim (active utterance)

    /// 今まさに喋られている最中のテキスト。
    /// final と同じ 22pt だが weight を regular に落として "未確定" を表現。
    /// 最後にカーソルが点滅 → "生きてる" 感を出す。
    /// final 化する時に同じ位置・同じサイズなので視覚的な "ジャンプ" が無い。
    private var interimLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(coordinator.interimText)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 2, height: 22)
                .opacity(cursorOn ? 1.0 : 0.0)
        }
    }
}
