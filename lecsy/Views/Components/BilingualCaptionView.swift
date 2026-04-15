//
//  BilingualCaptionView.swift
//  lecsy
//
//  Deepgram確定字幕（左＝原文）と GPT-4o Mini 翻訳（右＝母語）を左右並列表示。
//  両カラムは確定セグメント単位で同じ縦位置にスナップする。
//
//  参照: Deepgram/EXECUTION_PLAN.md W03
//

import SwiftUI

struct BilingualCaptionView: View {

    @ObservedObject var coordinator: TranscriptionCoordinator
    @ObservedObject var translation: TranslationStream

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            HStack(alignment: .top, spacing: 8) {
                sourceColumn
                Divider()
                    .background(.quaternary)
                targetColumn
            }
            .frame(maxHeight: 260)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
        .onChange(of: coordinator.liveSegments) { _, segments in
            // 新しい確定セグメントだけ翻訳キューに積む
            for seg in segments {
                translation.enqueue(seg)
            }
        }
    }

    // MARK: - Columns

    private var sourceColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(coordinator.liveSegments) { seg in
                        Text(seg.text)
                            .font(.system(.callout))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(seg.id)
                    }
                    if !coordinator.interimText.isEmpty {
                        Text(coordinator.interimText)
                            .font(.system(.callout))
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("src-interim")
                    }
                }
                .padding(10)
            }
            .onChange(of: coordinator.liveSegments.count) { _, _ in
                if let last = coordinator.liveSegments.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var targetColumn: some View {
        if translation.upgradeRequired {
            upgradeCTA
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(translation.translatedSegments) { seg in
                            translatedRow(seg)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: translation.translatedSegments.count) { _, _ in
                    if let last = translation.translatedSegments.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var upgradeCTA: some View {
        VStack(spacing: 10) {
            Image(systemName: "character.bubble")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Live translation unavailable")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Contact your organization admin for access.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func translatedRow(_ seg: TranslationStream.TranslatedSegment) -> some View {
        switch seg.status {
        case .pending:
            ProgressView()
                .scaleEffect(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(seg.id)
        case .done:
            Text(seg.translatedText)
                .font(.system(.callout))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(seg.id)
        case .failed:
            Text(seg.sourceText)
                .font(.system(.callout))
                .foregroundStyle(.orange.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(seg.id)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "character.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
            Text(translation.upgradeRequired ? "Live Captions" : "Bilingual Captions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("BETA")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.15)))
                .foregroundStyle(Color.blue)
            Spacer()
            if !translation.upgradeRequired {
                Text("→ \(translation.targetLang.uppercased())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
    }
}
