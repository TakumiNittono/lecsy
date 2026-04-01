//
//  LecsyWidgetAttributes.swift
//  LecsyWidget
//
//  Shared with main app target — this file is the SINGLE source of truth.
//  Both the app target and widget extension target must include this file
//  in their respective "Compile Sources" build phases.
//
//  Created on 2026/01/27.
//

import Foundation
import ActivityKit

/// Attribute definition for Live Activities
struct LecsyWidgetAttributes: ActivityAttributes {
    /// Dynamically updated content state
    public struct ContentState: Codable, Hashable {
        /// Recording elapsed time (in seconds)
        var recordingDuration: TimeInterval
        /// Whether recording is in progress
        var isRecording: Bool
        /// Recording start date (for system-driven timer display)
        var recordingStartDate: Date?
        /// Whether recording is paused
        var isPaused: Bool
    }

    /// Static attributes (lecture title, etc.)
    var lectureTitle: String
}

// MARK: - Preview Extensions
extension LecsyWidgetAttributes {
    static var preview: LecsyWidgetAttributes {
        LecsyWidgetAttributes(lectureTitle: "Introduction to Economics - Lecture 1")
    }
}

extension LecsyWidgetAttributes.ContentState {
    static var preview: LecsyWidgetAttributes.ContentState {
        LecsyWidgetAttributes.ContentState(
            recordingDuration: 3661.0,
            isRecording: true,
            recordingStartDate: Date().addingTimeInterval(-3661),
            isPaused: false
        )
    }
}
