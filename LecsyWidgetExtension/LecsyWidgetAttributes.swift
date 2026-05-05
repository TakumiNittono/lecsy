//
//  LecsyWidgetAttributes.swift
//  lecsy
//
//  Shared with widget extension target — this file MUST stay byte-for-byte
//  in sync with `LecsyWidgetExtension/LecsyWidgetAttributes.swift`. Both
//  the app target and the widget extension target include this file in
//  their respective "Compile Sources" build phases.
//
//  Created on 2026/01/27.
//

import Foundation
import ActivityKit

/// Attribute definition for Live Activities
struct LecsyWidgetAttributes: ActivityAttributes {
    /// Dynamically updated content state
    public struct ContentState: Codable, Hashable {
        /// Phase machine: a single Live Activity now spans
        ///   recording (& paused) → transcribing → done
        /// so the user can see the post-stop WhisperKit batch progress
        /// from the lock screen / Dynamic Island without having to
        /// re-open Lecsy. Default is `.recording` so old call sites
        /// that omit the field keep working unchanged.
        enum Phase: String, Codable, Hashable {
            case recording
            case paused
            case transcribing
            case done
        }

        /// Recording elapsed time (in seconds)
        var recordingDuration: TimeInterval
        /// Whether recording is in progress
        var isRecording: Bool
        /// Recording start date (for system-driven timer display)
        var recordingStartDate: Date?
        /// Whether recording is paused
        var isPaused: Bool

        /// Current phase. The widget UI branches on this — `.recording`
        /// keeps the existing red-mic look, `.transcribing` switches to
        /// a blue progress card, `.done` shows a brief "Done" before
        /// the activity is dismissed.
        var phase: Phase
        /// 1-based chunk index inside the WhisperKit chunked transcription
        /// loop (`runChunkedTranscription`). nil when not transcribing.
        var transcribeChunkIndex: Int?
        /// Total chunk count for the in-flight transcription. nil when not transcribing.
        var transcribeChunkTotal: Int?
        /// Estimated remaining seconds. Computed by TranscriptionProgressService
        /// from elapsed/index; nil for the first chunk (not enough data) or
        /// when the transcription is not chunk-based.
        var transcribeETASeconds: Int?

        init(
            recordingDuration: TimeInterval,
            isRecording: Bool,
            recordingStartDate: Date?,
            isPaused: Bool,
            phase: Phase = .recording,
            transcribeChunkIndex: Int? = nil,
            transcribeChunkTotal: Int? = nil,
            transcribeETASeconds: Int? = nil
        ) {
            self.recordingDuration = recordingDuration
            self.isRecording = isRecording
            self.recordingStartDate = recordingStartDate
            self.isPaused = isPaused
            self.phase = phase
            self.transcribeChunkIndex = transcribeChunkIndex
            self.transcribeChunkTotal = transcribeChunkTotal
            self.transcribeETASeconds = transcribeETASeconds
        }

        // Custom decoder so older payloads (no phase / no chunk fields)
        // still round-trip cleanly. ActivityKit is process-local so we
        // don't expect cross-version traffic, but the lenient decoder
        // also makes the type easier to evolve in tests.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            recordingDuration = try c.decode(TimeInterval.self, forKey: .recordingDuration)
            isRecording = try c.decode(Bool.self, forKey: .isRecording)
            recordingStartDate = try c.decodeIfPresent(Date.self, forKey: .recordingStartDate)
            isPaused = try c.decode(Bool.self, forKey: .isPaused)
            phase = (try? c.decode(Phase.self, forKey: .phase)) ?? .recording
            transcribeChunkIndex = try? c.decode(Int.self, forKey: .transcribeChunkIndex)
            transcribeChunkTotal = try? c.decode(Int.self, forKey: .transcribeChunkTotal)
            transcribeETASeconds = try? c.decode(Int.self, forKey: .transcribeETASeconds)
        }
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

    /// Preview for the new transcribing phase — used by the widget canvas.
    static var transcribingPreview: LecsyWidgetAttributes.ContentState {
        LecsyWidgetAttributes.ContentState(
            recordingDuration: 5400,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: false,
            phase: .transcribing,
            transcribeChunkIndex: 47,
            transcribeChunkTotal: 119,
            transcribeETASeconds: 138
        )
    }
}
