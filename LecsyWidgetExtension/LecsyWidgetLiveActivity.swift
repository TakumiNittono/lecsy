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
            // Lock screen UI — branches on phase so the same Activity
            // can carry the user from recording → transcribing → done
            // without having to be re-created.
            Group {
                switch context.state.phase {
                case .recording, .paused:
                    recordingLockScreen(context: context)
                case .transcribing:
                    transcribingLockScreen(context: context)
                case .done:
                    doneLockScreen(context: context)
                }
            }
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: expandedLeadingIcon(for: context.state))
                            .foregroundColor(expandedLeadingTint(for: context.state))
                            .font(.title3)
                        Text(expandedLeadingText(for: context.state))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(for: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.lectureTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if context.state.phase == .transcribing,
                           let idx = context.state.transcribeChunkIndex,
                           let total = context.state.transcribeChunkTotal {
                            ProgressView(value: Double(idx) / Double(max(1, total)))
                                .progressViewStyle(.linear)
                                .tint(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: compactLeadingIcon(for: context.state))
                    .foregroundColor(compactLeadingTint(for: context.state))
            } compactTrailing: {
                compactTrailing(for: context.state)
            } minimal: {
                Image(systemName: compactLeadingIcon(for: context.state))
                    .foregroundColor(compactLeadingTint(for: context.state))
            }
            .widgetURL(URL(string: "lecsy://record"))
            .keylineTint(keylineTint(for: context.state))
        }
    }

    // MARK: - Lock screen branches

    @ViewBuilder
    private func recordingLockScreen(context: ActivityViewContext<LecsyWidgetAttributes>) -> some View {
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
    }

    @ViewBuilder
    private func transcribingLockScreen(context: ActivityViewContext<LecsyWidgetAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "waveform.badge.mic")
                    .foregroundColor(context.state.isPaused ? .orange : .blue)
                    .font(.title3)
                Text(context.state.isPaused ? "Paused" : "Transcribing")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
            }

            if context.state.isPaused {
                // Paused 時は bar も chunk 数も出さない (= 「動いてる」風表示を
                // 構造的に消す)。ユーザーへの action 指示だけ残す。
                Text("Open Lecsy to continue transcription")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if let idx = context.state.transcribeChunkIndex,
                      let total = context.state.transcribeChunkTotal {
                ProgressView(value: Double(idx) / Double(max(1, total)))
                    .progressViewStyle(.linear)
                    .tint(.blue)
                Text("\(idx) / \(total) chunks")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            } else {
                Text("Preparing on-device AI...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(context.attributes.lectureTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    @ViewBuilder
    private func doneLockScreen(context: ActivityViewContext<LecsyWidgetAttributes>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcript ready")
                    .font(.headline)
                Text(context.attributes.lectureTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    // MARK: - Dynamic Island helpers

    private func expandedLeadingIcon(for state: LecsyWidgetAttributes.ContentState) -> String {
        switch state.phase {
        case .recording: return "mic.fill"
        case .paused:    return "pause.fill"
        case .transcribing: return "waveform.badge.mic"
        case .done:      return "checkmark.circle.fill"
        }
    }

    private func expandedLeadingTint(for state: LecsyWidgetAttributes.ContentState) -> Color {
        switch state.phase {
        case .recording: return .red
        case .paused:    return .orange
        case .transcribing: return .blue
        case .done:      return .green
        }
    }

    private func expandedLeadingText(for state: LecsyWidgetAttributes.ContentState) -> String {
        switch state.phase {
        case .recording: return "Recording"
        case .paused:    return "Paused"
        case .transcribing: return "Transcribing"
        case .done:      return "Done"
        }
    }

    @ViewBuilder
    private func expandedTrailing(for state: LecsyWidgetAttributes.ContentState) -> some View {
        switch state.phase {
        case .recording, .paused:
            if let startDate = state.recordingStartDate, state.isRecording, !state.isPaused {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(formatDuration(state.recordingDuration))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        case .transcribing:
            if state.isPaused {
                // Compact 表示でもオレンジで Paused を可視化。
                Image(systemName: "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
            } else if let eta = state.transcribeETASeconds {
                Text(formatETA(eta))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.blue)
            } else if let idx = state.transcribeChunkIndex,
                      let total = state.transcribeChunkTotal {
                Text("\(idx)/\(total)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.blue)
            } else {
                ProgressView()
            }
        case .done:
            Image(systemName: "checkmark")
                .font(.headline)
                .foregroundColor(.green)
        }
    }

    private func compactLeadingIcon(for state: LecsyWidgetAttributes.ContentState) -> String {
        switch state.phase {
        case .recording: return "mic.fill"
        case .paused:    return "pause.fill"
        case .transcribing: return "waveform.badge.mic"
        case .done:      return "checkmark.circle.fill"
        }
    }

    private func compactLeadingTint(for state: LecsyWidgetAttributes.ContentState) -> Color {
        switch state.phase {
        case .recording: return .red
        case .paused:    return .orange
        case .transcribing: return .blue
        case .done:      return .green
        }
    }

    @ViewBuilder
    private func compactTrailing(for state: LecsyWidgetAttributes.ContentState) -> some View {
        switch state.phase {
        case .recording, .paused:
            if let startDate = state.recordingStartDate, state.isRecording, !state.isPaused {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(formatDuration(state.recordingDuration))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        case .transcribing:
            if let idx = state.transcribeChunkIndex,
               let total = state.transcribeChunkTotal {
                Text("\(Int(Double(idx) / Double(max(1, total)) * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.blue)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.green)
        }
    }

    private func keylineTint(for state: LecsyWidgetAttributes.ContentState) -> Color {
        switch state.phase {
        case .recording: return .red
        case .paused:    return .orange
        case .transcribing: return .blue
        case .done:      return .green
        }
    }

    // MARK: - Helpers (recording-phase legacy)

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

    private func formatETA(_ seconds: Int) -> String {
        if seconds < 60 {
            return "~\(seconds)s"
        }
        let minutes = Int((Double(seconds) / 60.0).rounded())
        return "~\(minutes) min"
    }
}

#Preview("Lock Screen — Recording", as: .content, using: LecsyWidgetAttributes.preview) {
    LecsyWidgetLiveActivity()
} contentStates: {
    LecsyWidgetAttributes.ContentState.preview
}

#Preview("Lock Screen — Transcribing", as: .content, using: LecsyWidgetAttributes.preview) {
    LecsyWidgetLiveActivity()
} contentStates: {
    LecsyWidgetAttributes.ContentState.transcribingPreview
}
