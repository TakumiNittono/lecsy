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
    private var barMaxHeight: CGFloat { horizontalSizeClass == .regular ? 64 : 48 }
    private var frameHeight: CGFloat { horizontalSizeClass == .regular ? 72 : 56 }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let dataIndex = max(0, levels.count - barCount) + index
                let level = (dataIndex >= 0 && dataIndex < levels.count) ? CGFloat(levels[dataIndex]) : 0
                // Apply easing curve to make small levels more visible
                let boosted = pow(level, 0.6)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: level))
                    .frame(width: barWidth, height: max(3, boosted * barMaxHeight))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
        .frame(height: frameHeight)
    }

    /// Dynamic gradient color based on audio level
    private func barColor(for level: CGFloat) -> Color {
        if level > 0.85 {
            return Color.red.opacity(0.9)
        } else if level > 0.6 {
            return Color.orange.opacity(0.85)
        } else if level > 0.15 {
            return Color.blue.opacity(0.75)
        } else {
            return Color.blue.opacity(0.4)
        }
    }
}

#Preview {
    AudioWaveformView(levels: (0..<30).map { _ in Float.random(in: 0...1) })
}
