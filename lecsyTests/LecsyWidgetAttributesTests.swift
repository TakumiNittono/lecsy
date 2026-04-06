//
//  LecsyWidgetAttributesTests.swift
//  lecsyTests
//
//  Tests for LecsyWidgetAttributes and ContentState
//

import Testing
import Foundation
@testable import lecsy

struct LecsyWidgetAttributesTests {

    @Test func attributesInit() {
        let attrs = LecsyWidgetAttributes(lectureTitle: "Economics 101")
        #expect(attrs.lectureTitle == "Economics 101")
    }

    @Test func contentStateInit() {
        let now = Date()
        let state = LecsyWidgetAttributes.ContentState(
            recordingDuration: 120.0,
            isRecording: true,
            recordingStartDate: now,
            isPaused: false
        )
        #expect(state.recordingDuration == 120.0)
        #expect(state.isRecording == true)
        #expect(state.recordingStartDate == now)
        #expect(state.isPaused == false)
    }

    @Test func contentStatePaused() {
        let state = LecsyWidgetAttributes.ContentState(
            recordingDuration: 60.0,
            isRecording: true,
            recordingStartDate: nil,
            isPaused: true
        )
        #expect(state.isPaused == true)
        #expect(state.recordingStartDate == nil)
    }

    @Test func contentStateNotRecording() {
        let state = LecsyWidgetAttributes.ContentState(
            recordingDuration: 0,
            isRecording: false,
            recordingStartDate: nil,
            isPaused: false
        )
        #expect(state.isRecording == false)
        #expect(state.recordingDuration == 0)
    }

    @Test func previewAttributes() {
        let preview = LecsyWidgetAttributes.preview
        #expect(!preview.lectureTitle.isEmpty)
    }

    @Test func previewContentState() {
        let preview = LecsyWidgetAttributes.ContentState.preview
        #expect(preview.isRecording == true)
        #expect(preview.isPaused == false)
        #expect(preview.recordingDuration > 0)
        #expect(preview.recordingStartDate != nil)
    }

    @Test func contentStateHashable() {
        let a = LecsyWidgetAttributes.ContentState(
            recordingDuration: 10, isRecording: true, recordingStartDate: nil, isPaused: false
        )
        let b = LecsyWidgetAttributes.ContentState(
            recordingDuration: 10, isRecording: true, recordingStartDate: nil, isPaused: false
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func contentStateCodable() throws {
        let now = Date(timeIntervalSince1970: 1700000000)
        let original = LecsyWidgetAttributes.ContentState(
            recordingDuration: 300.5,
            isRecording: true,
            recordingStartDate: now,
            isPaused: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            LecsyWidgetAttributes.ContentState.self, from: data
        )

        #expect(decoded.recordingDuration == original.recordingDuration)
        #expect(decoded.isRecording == original.isRecording)
        #expect(decoded.isPaused == original.isPaused)
    }
}
