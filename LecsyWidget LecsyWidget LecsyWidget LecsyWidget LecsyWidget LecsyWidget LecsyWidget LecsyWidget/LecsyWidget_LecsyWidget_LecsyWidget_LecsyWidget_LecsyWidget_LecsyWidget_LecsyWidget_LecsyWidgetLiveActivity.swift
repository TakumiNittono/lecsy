//
//  LecsyWidgetLiveActivity.swift
//  LecsyWidget
//
//  Created on 2026/01/27.
//

import ActivityKit
import WidgetKit
import SwiftUI

// LecsyWidgetAttributesはメインアプリのlecsy/Models/LecsyWidgetAttributes.swiftから共有されます

struct LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LecsyWidgetAttributes.self) { context in
            // ロック画面UI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Recording")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // 経過時間表示
                Text(formatDuration(context.state.recordingDuration))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                
                // 講義タイトル
                Text(context.attributes.lectureTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Tap to open app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI（Dynamic Islandが展開された時）
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        Text("Recording")
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.recordingDuration))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.lectureTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text("Tap to stop recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                // Compact Leading（左側）
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            } compactTrailing: {
                // Compact Trailing（右側）- 時間表示
                Text(formatDuration(context.state.recordingDuration))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                // Minimal（最小表示）- 録音アイコンのみ
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            }
            .widgetURL(URL(string: "lecsy://record"))
            .keylineTint(Color.red)
        }
    }
    
    /// 時間をフォーマット（HH:MM:SS形式）
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview("Lock Screen", as: .content, using: LecsyWidgetAttributes.preview) {
    LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetLiveActivity()
} contentStates: {
    LecsyWidgetAttributes.ContentState.preview
}
