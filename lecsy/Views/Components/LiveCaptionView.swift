//
//  LiveCaptionView.swift
//  lecsy
//
//  リアルタイム字幕パネル。過去セグメントも全て保持しスクロールで遡れる。
//  最新1行はテレプロンプター式に大きく強調、古いものはフェードしつつ読める。
//

import SwiftUI

struct LiveCaptionView: View {

    @ObservedObject var coordinator: TranscriptionCoordinator
    @State private var pulse: Bool = false
    @State private var cursorOn: Bool = true

    // prepare 中は "Connecting"、接続済で字幕あり/なしで "LIVE"/"Listening" 表記を切替。
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

            Divider().opacity(0.25)

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
            // カーソル点滅 (interim テキスト用)
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                cursorOn.toggle()
            }
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

    /// 接続状態のピル。CONNECTING→青、LIVE→赤、LISTENING→赤（発話待ち）。
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

            if phase == .live, !coordinator.liveSegments.isEmpty {
                Text("· \(coordinator.liveSegments.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(statusTint.opacity(0.12))
        )
    }

    private var statusLabel: String {
        switch phase {
        case .connecting: return "CONNECTING"
        case .listening:  return "LIVE"
        case .live:       return "LIVE"
        }
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

    /// prepare 中: 接続中であることを明確に、安心感を与える視覚
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

    /// 接続済だが発話まだ: 聞き取り可能を明示、話しかけるよう促す
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
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(all.enumerated()), id: \.element.id) { pair in
                        let (idx, seg) = pair
                        let isLatestFinal = (idx == lastFinalIndex) && !hasInterim
                        captionLine(
                            text: seg.text,
                            emphasis: emphasis(for: idx, total: total, isLatestFinal: isLatestFinal)
                        )
                        .id(seg.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .identity
                        ))
                    }

                    if hasInterim {
                        interimLine
                            .id("interim")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)
            .onChange(of: coordinator.liveSegments.count) { _, _ in
                withAnimation(.easeOut(duration: 0.35)) {
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
        case latest    // 最新確定: 大きく濃く
        case recent    // 直近数行: 中
        case older     // 更に古い: 読めるが淡い
    }

    /// 最新が latest、その前2行が recent、それより古いは older。
    /// 履歴は全て可読性を保つ（displayWindow による非表示はしない）。
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
            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.primary)
                .lineSpacing(4)
        case .recent:
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(Color.primary.opacity(0.78))
                .lineSpacing(3)
        case .older:
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary.opacity(0.55))
                .lineSpacing(2)
        }
    }

    /// interim: italic + 点滅カーソル。 "今まさに喋られている" 視覚的サイン。
    private var interimLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(coordinator.interimText)
                .font(.system(size: 17))
                .italic()
                .foregroundStyle(Color.secondary.opacity(0.8))
                .lineSpacing(3)
            Rectangle()
                .fill(Color.secondary.opacity(0.8))
                .frame(width: 2, height: 18)
                .opacity(cursorOn ? 1.0 : 0.0)
        }
    }
}
