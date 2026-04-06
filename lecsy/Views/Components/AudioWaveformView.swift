//
//  AudioWaveformView.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import SwiftUI

struct AudioWaveformView: View {
    let levels: [Float]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var barCount: Int { horizontalSizeClass == .regular ? 50 : 36 }
    private var barWidth: CGFloat { horizontalSizeClass == .regular ? 5 : 3 }
    private var barSpacing: CGFloat { 2 }
    private var barMaxHeight: CGFloat { horizontalSizeClass == .regular ? 64 : 52 }
    private var frameHeight: CGFloat { horizontalSizeClass == .regular ? 72 : 60 }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let dataIndex = max(0, levels.count - barCount) + index
                let level = (dataIndex >= 0 && dataIndex < levels.count) ? CGFloat(levels[dataIndex]) : 0
                let boosted = pow(level, 0.55)
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barGradient(for: level))
                    .frame(width: barWidth, height: max(3, boosted * barMaxHeight))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: frameHeight)
        .padding(.horizontal, 8)
    }

    private func barGradient(for level: CGFloat) -> some ShapeStyle {
        if level > 0.85 {
            return Color.red.opacity(0.85)
        } else if level > 0.6 {
            return Color.orange.opacity(0.8)
        } else if level > 0.25 {
            return Color.blue.opacity(0.7)
        } else {
            return Color.blue.opacity(0.3)
        }
    }
}

#Preview {
    AudioWaveformView(levels: (0..<36).map { _ in Float.random(in: 0...1) })
        .padding()
}
