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

struct LecsyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LecsyWidgetAttributes.self) { context in
            // Lock screen UI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: lockScreenIcon(for: context.state))
                        .foregroundColor(lockScreenIconColor(for: context.state))
                        .font(.title2)
                    Text(lockScreenStatusText(for: context.state))
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                // Timer display (system auto-updates every second)
                if let startDate = context.state.recordingStartDate,
                   context.state.isRecording, !context.state.isPaused {
                    Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                } else {
                    Text(formatDuration(context.state.recordingDuration))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(context.state.isRecording ? .primary : .secondary)
                }

                // Lecture title
                Text(context.attributes.lectureTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if context.state.isRecording {
                    Text("Tap to open app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Recording saved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                            .foregroundColor(context.state.isPaused ? .orange : .red)
                            .font(.title3)
                        Text(context.state.isPaused ? "Paused" : "Recording")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let startDate = context.state.recordingStartDate,
                       context.state.isRecording, !context.state.isPaused {
                        Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    } else {
                        Text(formatDuration(context.state.recordingDuration))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.lectureTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .foregroundColor(context.state.isPaused ? .orange : .red)
            } compactTrailing: {
                if let startDate = context.state.recordingStartDate,
                   context.state.isRecording, !context.state.isPaused {
                    Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text(formatDuration(context.state.recordingDuration))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .foregroundColor(context.state.isPaused ? .orange : .red)
            }
            .widgetURL(URL(string: "lecsy://record"))
            .keylineTint(context.state.isPaused ? Color.orange : Color.red)
        }
    }
    
    // MARK: - Helpers

    private func lockScreenIcon(for state: LecsyWidgetAttributes.ContentState) -> String {
        if !state.isRecording { return "checkmark.circle.fill" }
        return state.isPaused ? "pause.fill" : "mic.fill"
    }

    private func lockScreenIconColor(for state: LecsyWidgetAttributes.ContentState) -> Color {
        if !state.isRecording { return .green }
        return state.isPaused ? .orange : .red
    }

    private func lockScreenStatusText(for state: LecsyWidgetAttributes.ContentState) -> String {
        if !state.isRecording { return "Done" }
        return state.isPaused ? "Paused" : "Recording"
    }

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
    LecsyWidgetLiveActivity()
} contentStates: {
    LecsyWidgetAttributes.ContentState.preview
}
