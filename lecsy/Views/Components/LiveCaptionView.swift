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

    var body: some View {
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().opacity(0.3)

            captionScroll
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
        )
        .onAppear { pulse = true }
    }

    // MARK: - Status bar

    /// prepare 中は "Connecting"、接続済で字幕あり/なしで "LIVE"/"Listening" 表記を切替。
    private enum Phase { case connecting, listening, live }
    private var phase: Phase {
        if coordinator.isPreparing && !coordinator.isLiveActive { return .connecting }
        return coordinator.liveSegments.isEmpty && coordinator.interimText.isEmpty
            ? .listening
            : .live
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(phase == .connecting ? Color.blue : Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.0 : 0.6)
                .opacity(pulse ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

            Text(phase == .connecting ? "CONNECTING" : "LIVE")
                .font(.caption.weight(.bold))
                .foregroundStyle(phase == .connecting ? Color.blue : Color.red)
                .tracking(1.2)

            if !coordinator.liveSegments.isEmpty {
                Text("\(coordinator.liveSegments.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let err = coordinator.liveError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 180, alignment: .trailing)
            } else {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Auto")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Caption content

    private var captionScroll: some View {
        let all = coordinator.liveSegments
        let total = all.count
        let lastFinalIndex = total - 1
        let hasInterim = !coordinator.interimText.isEmpty

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    if all.isEmpty && !hasInterim {
                        emptyState
                    } else {
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
                            captionLine(text: coordinator.interimText, emphasis: .interim)
                                .id("interim")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
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
        case interim   // 未確定中: italic
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
        case .interim:
            Text(text)
                .font(.system(size: 17))
                .italic()
                .foregroundStyle(Color.secondary.opacity(0.7))
                .lineSpacing(3)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(spacing: 10) {
            if phase == .connecting {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting captions…")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "waveform")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text("Listening…")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
