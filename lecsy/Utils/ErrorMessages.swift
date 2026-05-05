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
                    title: "Audio File Needs Repair",
                    message: "We're trying to repair the recording file automatically. Tap Retry — if it keeps failing, restart your device and try once more."
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
                // 大講堂・遠距離マイク・低音量で WhisperKit が一切認識しなかった時に着地する。
                // お父様 2026-04-24 / Peter 2026-05-05 系のシナリオの本命メッセージなので、
                // 「次に試すべき 3 手」を必ず並べる。Pro お試しに繋げる文言は launch 後に追加。
                return UserFacingError(
                    title: "No Speech Detected",
                    message: "We couldn't pick up speech from the recording. Things to try:\n• Move the phone closer to the speaker (within 2-3 m)\n• Tap Retry — we'll re-process with audio boost\n• Record a shorter test (10-30 s) to confirm the mic is working"
                )
            case .transcriptionFailed:
                return UserFacingError(
                    title: "Transcription Failed",
                    message: "Something went wrong. Tap Retry. If it fails again, keep Lecsy in the foreground (don't switch apps) during the next attempt."
                )
            case .transcriptionTimedOut:
                // 旧文言「30 分以下に分割して」は誤誘導。実際の原因はほぼ全て
                // background kill / GPU thermal / cache miss であり、長さは関係ない。
                return UserFacingError(
                    title: "Transcription Took Too Long",
                    message: "Keep Lecsy open in the foreground and tap Retry. If it keeps timing out, restart your device — that clears any thermal throttling."
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
