//
//  ErrorMessagesTests.swift
//  lecsyTests
//
//  Tests for ErrorMessages utility
//

import Testing
import Foundation
@testable import lecsy

struct ErrorMessagesTests {

    // MARK: - Recording Errors

    @Test func recordingPermissionDenied() {
        let error = ErrorMessages.forRecording(RecordingService.RecordingError.permissionDenied)
        #expect(error.title == "Microphone Access Needed")
        #expect(error.actionLabel == "Open Settings")
        #expect(!error.message.isEmpty)
    }

    @Test func recordingFileCreationFailed() {
        let error = ErrorMessages.forRecording(RecordingService.RecordingError.fileCreationFailed)
        #expect(error.title == "Could Not Start Recording")
        #expect(error.actionLabel == nil)
    }

    @Test func recordingFailed() {
        let error = ErrorMessages.forRecording(RecordingService.RecordingError.recordingFailed)
        #expect(error.title == "Recording Failed")
        #expect(error.actionLabel == nil)
    }

    @Test func recordingInsufficientStorage() {
        let error = ErrorMessages.forRecording(RecordingService.RecordingError.insufficientStorage)
        #expect(error.title == "Storage Full")
        #expect(error.actionLabel == nil)
    }

    @Test func recordingUnknownError() {
        struct SomeError: Error {}
        let error = ErrorMessages.forRecording(SomeError())
        #expect(error.title == "Recording Error")
        #expect(error.message.contains("unexpected"))
    }

    // MARK: - Transcription Errors

    @Test func transcriptionModelNotLoaded() {
        let error = ErrorMessages.forTranscription(TranscriptionError.modelNotLoaded)
        #expect(error.title == "AI Model Not Ready")
    }

    @Test func transcriptionModelLoadFailed() {
        let error = ErrorMessages.forTranscription(TranscriptionError.modelLoadFailed("timeout"))
        #expect(error.title == "Model Download Failed")
        #expect(error.message.contains("timeout"))
    }

    @Test func transcriptionAudioLoadFailed() {
        let error = ErrorMessages.forTranscription(TranscriptionError.audioLoadFailed)
        #expect(error.title == "Audio Error")
    }

    @Test func transcriptionAudioFileNotFound() {
        let error = ErrorMessages.forTranscription(TranscriptionError.audioFileNotFound)
        #expect(error.title == "Recording Not Found")
    }

    @Test func transcriptionAudioFileTooShort() {
        let error = ErrorMessages.forTranscription(TranscriptionError.audioFileTooShort)
        #expect(error.title == "Recording Too Short")
    }

    @Test func transcriptionEmptyResult() {
        let error = ErrorMessages.forTranscription(TranscriptionError.emptyTranscriptionResult)
        #expect(error.title == "No Speech Detected")
    }

    @Test func transcriptionFailed() {
        let error = ErrorMessages.forTranscription(TranscriptionError.transcriptionFailed)
        #expect(error.title == "Transcription Failed")
    }

    @Test func transcriptionTimedOut() {
        let error = ErrorMessages.forTranscription(TranscriptionError.transcriptionTimedOut)
        #expect(error.title == "Transcription Too Slow")
    }

    @Test func transcriptionUnknownError() {
        struct SomeError: Error {}
        let error = ErrorMessages.forTranscription(SomeError())
        #expect(error.title == "Transcription Error")
        #expect(error.message.contains("unexpected"))
    }
}

// MARK: - UserFacingError Tests

struct UserFacingErrorTests {

    @Test func initWithAllFields() {
        let error = UserFacingError(
            title: "Title", message: "Message", actionLabel: "Action"
        )
        #expect(error.title == "Title")
        #expect(error.message == "Message")
        #expect(error.actionLabel == "Action")
    }

    @Test func initWithoutActionLabel() {
        let error = UserFacingError(title: "T", message: "M")
        #expect(error.actionLabel == nil)
    }
}
