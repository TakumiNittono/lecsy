//
//  LecsyWidgetAttributes.swift
//  lecsy
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
            recordingDuration: 3661.0, // 1 hour 1 minute 1 second
            isRecording: true
        )
    }
}
