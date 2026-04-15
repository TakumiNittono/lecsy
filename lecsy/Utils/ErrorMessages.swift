//
//  ErrorMessages.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import Foundation

struct UserFacingError {
    let title: String
    let message: String
    let actionLabel: String?

    init(title: String, message: String, actionLabel: String? = nil) {
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
    }
}

enum ErrorMessages {
    static func forRecording(_ error: Error) -> UserFacingError {
        if let recordingError = error as? RecordingService.RecordingError {
            switch recordingError {
            case .permissionDenied:
                return UserFacingError(
                    title: "Microphone Access Needed",
                    message: "Lecsy needs microphone access to record lectures. Please enable it in Settings.",
                    actionLabel: "Open Settings"
                )
            case .fileCreationFailed:
                return UserFacingError(
                    title: "Could Not Start Recording",
                    message: "There was a problem preparing the recording file. Please try again."
                )
            case .recordingFailed:
                return UserFacingError(
                    title: "Recording Failed",
                    message: "Something went wrong while starting the recording. Please close other audio apps and try again."
                )
            case .insufficientStorage:
                return UserFacingError(
                    title: "Storage Full",
                    message: "Your device doesn't have enough free space. Please free up at least 100 MB and try again."
                )
            }
        }

        return UserFacingError(
            title: "Recording Error",
            message: "An unexpected error occurred. Please try again."
        )
    }

    static func forTranscription(_ error: Error) -> UserFacingError {
        if let transcriptionError = error as? TranscriptionError {
            switch transcriptionError {
            case .modelNotLoaded:
                return UserFacingError(
                    title: "AI Model Not Ready",
                    message: "The AI model needs to be downloaded first. Go to Settings to download it."
                )
            case .modelLoadFailed(let detail):
                return UserFacingError(
                    title: "Model Download Failed",
                    message: "Could not download the AI model: \(detail)"
                )
            case .audioLoadFailed:
                return UserFacingError(
                    title: "Audio Error",
                    message: "Could not read the recording file. The file may be corrupted."
                )
            case .audioFileNotFound:
                return UserFacingError(
                    title: "Recording Not Found",
                    message: "The recording file could not be found. It may have been deleted. Please try recording again."
                )
            case .audioFileTooShort:
                return UserFacingError(
                    title: "Recording Too Short",
                    message: "The recording is too short to transcribe. Please record for at least a few seconds."
                )
            case .emptyTranscriptionResult:
                return UserFacingError(
                    title: "No Speech Detected",
                    message: "No speech was detected in the recording. Please make sure you are speaking clearly and the microphone is not blocked, then try again."
                )
            case .transcriptionFailed:
                return UserFacingError(
                    title: "Transcription Failed",
                    message: "Something went wrong during transcription. Please try again."
                )
            case .transcriptionTimedOut:
                return UserFacingError(
                    title: "Transcription Too Slow",
                    message: "The recording may be too long for this device. Try recording shorter segments (under 30 minutes)."
                )
            case .alreadyProcessing:
                return UserFacingError(
                    title: "Already Processing",
                    message: "Transcription is already in progress for this recording."
                )
            }
        }

        return UserFacingError(
            title: "Transcription Error",
            message: "An unexpected error occurred during transcription. Please try again."
        )
    }

    /// Convert any raw error into a short, user-friendly string.
    /// Use this instead of `error.localizedDescription` anywhere in the UI.
    static func friendly(_ error: Error) -> String {
        let raw = "\(error)"
        if raw.contains("NSURLErrorDomain") || raw.contains("connection was lost")
            || raw.contains("timed out") || raw.contains("not connected")
            || raw.contains("offline") || raw.contains("No Internet") {
            return "Network error — please check your connection and try again."
        }
        if raw.contains("401") || raw.contains("403") || raw.contains("JWT") {
            return "Session expired. Please sign out and sign in again."
        }
        if raw.contains("429") || raw.contains("rate limit") {
            return "Too many requests — please wait a moment and try again."
        }
        if raw.contains("500") || raw.contains("502") || raw.contains("503") {
            return "Server is temporarily unavailable. Please try again later."
        }
        return "Something went wrong. Please try again."
    }
}
