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

    private var barCount: Int { horizontalSizeClass == .regular ? 50 : 30 }
    private var barWidth: CGFloat { horizontalSizeClass == .regular ? 6 : 4 }
    private var barMaxHeight: CGFloat { horizontalSizeClass == .regular ? 64 : 44 }
    private var frameHeight: CGFloat { horizontalSizeClass == .regular ? 72 : 48 }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let level = index < levels.count ? CGFloat(levels[index]) : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: level))
                    .frame(width: barWidth, height: max(4, level * barMaxHeight))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: frameHeight)
    }

    /// Dynamic gradient color based on audio level
    private func barColor(for level: CGFloat) -> Color {
        if level > 0.85 {
            return Color.red.opacity(0.8)
        } else if level > 0.6 {
            return Color.orange.opacity(0.8)
        } else {
            return Color.blue.opacity(0.7)
        }
    }
}

#Preview {
    AudioWaveformView(levels: (0..<30).map { _ in Float.random(in: 0...1) })
}
