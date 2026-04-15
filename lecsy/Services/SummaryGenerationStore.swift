//
//  SummaryGenerationStore.swift
//  lecsy
//
//  View-independent store that owns in-progress AI summary generation tasks
//  keyed by lecture id. LectureDetailView reads from here instead of holding
//  local @State so that:
//    1. Navigating away does NOT cancel the generation — the task keeps
//       running and the result is auto-saved to LectureStore on completion.
//    2. Coming back to the same lecture restores the live streaming state.
//

import Foundation
import Combine

@MainActor
final class SummaryGenerationStore: ObservableObject {
    static let shared = SummaryGenerationStore()

    struct State: Equatable {
        var loading: Bool = false
        var streamingText: String = ""
        var partialResult: SummaryService.SummaryResult?
        var error: String?
    }

    @Published private(set) var states: [UUID: State] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func state(for id: UUID) -> State {
        states[id] ?? State()
    }

    func isRunning(_ id: UUID) -> Bool {
        states[id]?.loading == true
    }

    /// Start (or restart) summary generation for a lecture. Safe to call
    /// while another generation is running for the same lecture — the
    /// previous task is cancelled first.
    func start(lecture: Lecture, content: String, outputLanguage: String) {
        tasks[lecture.id]?.cancel()
        states[lecture.id] = State(loading: true, streamingText: "", partialResult: nil, error: nil)

        // Wallet guard — mirrors the cap that used to live in LectureDetailView.
        let maxChars = 100_000
        var capped = content
        if capped.count > maxChars {
            AppLogger.warning("Summary content unexpectedly large: \(capped.count) chars — truncating to \(maxChars)", category: .transcription)
            capped = String(capped.prefix(maxChars))
        }

        let lectureId = lecture.id
        let title = lecture.title
        let duration = lecture.duration
        let language = lecture.language.rawValue

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = SummaryService.shared.streamSummary(
                    title: title,
                    content: capped,
                    durationSeconds: duration,
                    language: language,
                    outputLanguage: outputLanguage
                )
                var finalResult: SummaryService.SummaryResult?
                for try await event in stream {
                    if Task.isCancelled { return }
                    switch event {
                    case .partialText(let text):
                        var s = self.states[lectureId] ?? State()
                        s.streamingText = text
                        s.partialResult = SummaryService.shared.parseStreamedMarkdown(text)
                        self.states[lectureId] = s
                    case .finished(let result):
                        finalResult = result
                    }
                }
                guard let result = finalResult else {
                    throw SummaryService.SummaryError.summarizeFailed("Empty response")
                }

                // Persist to LectureStore so it survives navigation & restarts.
                if var stored = LectureStore.shared.lectures.first(where: { $0.id == lectureId }) {
                    stored.cachedSummary = result
                    stored.cachedSummaryLanguage = outputLanguage
                    LectureStore.shared.updateLecture(stored)
                }

                var s = self.states[lectureId] ?? State()
                s.loading = false
                s.streamingText = ""
                s.partialResult = result
                s.error = nil
                self.states[lectureId] = s
            } catch {
                if Task.isCancelled { return }
                var s = self.states[lectureId] ?? State()
                s.loading = false
                s.error = error.localizedDescription
                self.states[lectureId] = s
            }
            self.tasks[lectureId] = nil
        }
        tasks[lectureId] = task
    }

    func cancel(_ id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        var s = states[id] ?? State()
        s.loading = false
        states[id] = s
    }

    func clearError(_ id: UUID) {
        var s = states[id] ?? State()
        s.error = nil
        states[id] = s
    }
}
