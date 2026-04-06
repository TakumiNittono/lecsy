//
//  LectureStoreTests.swift
//  lecsyTests
//
//  Tests for LectureStore persistence and CRUD operations.
//  Uses isolated temp directories to avoid affecting real data.
//

import Testing
import Foundation
import Combine
@testable import lecsy

// MARK: - Testable LectureStore

/// A subclass that uses an isolated temp directory for testing,
/// avoiding interference with real user data.
@MainActor
final class TestableLectureStore: ObservableObject {
    @Published var lectures: [Lecture] = []

    private let storageURL: URL
    private let backupStorageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL) {
        storageURL = directory.appendingPathComponent("lectures.json")
        backupStorageURL = directory.appendingPathComponent("lectures_backup.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func addLecture(_ lecture: Lecture) {
        lectures.append(lecture)
        saveLectures()
    }

    func updateLecture(_ lecture: Lecture) {
        guard let index = lectures.firstIndex(where: { $0.id == lecture.id }) else { return }
        lectures[index] = lecture
        saveLectures()
    }

    func deleteLecture(_ lecture: Lecture) {
        lectures.removeAll { $0.id == lecture.id }
        saveLectures()
    }

    func getLecture(by id: UUID) -> Lecture? {
        lectures.first { $0.id == id }
    }

    func searchLectures(query: String) -> [Lecture] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return lectures }
        let lowercasedQuery = trimmedQuery.lowercased()
        return lectures.filter { lecture in
            lecture.displayTitle.lowercased().contains(lowercasedQuery) ||
            lecture.transcriptText?.lowercased().contains(lowercasedQuery) ?? false
        }
    }

    func allCourseNames() -> [String] {
        Array(Set(lectures.compactMap { $0.courseName })).sorted()
    }

    func saveLectures() {
        guard let data = try? encoder.encode(lectures) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func loadLectures() {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            if let data = try? Data(contentsOf: storageURL),
               let decoded = try? decoder.decode([Lecture].self, from: data) {
                lectures = decoded
                return
            }
        }
        // Fallback to backup
        if FileManager.default.fileExists(atPath: backupStorageURL.path) {
            if let data = try? Data(contentsOf: backupStorageURL),
               let decoded = try? decoder.decode([Lecture].self, from: data) {
                lectures = decoded
                saveLectures() // Restore primary
                return
            }
        }
        lectures = []
    }

    func saveToBackup() {
        guard let data = try? encoder.encode(lectures) else { return }
        try? data.write(to: backupStorageURL, options: .atomic)
    }

    func corruptPrimaryFile() {
        try? "not json".data(using: .utf8)?.write(to: storageURL, options: .atomic)
    }

    func deletePrimaryFile() {
        try? FileManager.default.removeItem(at: storageURL)
    }

    func deleteAllData() {
        lectures = []
        try? FileManager.default.removeItem(at: storageURL)
        saveLectures()
    }
}

// MARK: - Helper

@MainActor
private func makeTempStore() -> (TestableLectureStore, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("lecsyTests_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return (TestableLectureStore(directory: dir), dir)
}

@MainActor
private func cleanUp(_ dir: URL) {
    try? FileManager.default.removeItem(at: dir)
}

// MARK: - Tests

struct LectureStoreTests {

    @Test @MainActor func addLecture() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        let lecture = Lecture(title: "Test", duration: 60)
        store.addLecture(lecture)

        #expect(store.lectures.count == 1)
        #expect(store.lectures.first?.title == "Test")
    }

    @Test @MainActor func addMultipleLectures() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "First", duration: 60))
        store.addLecture(Lecture(title: "Second", duration: 120))
        store.addLecture(Lecture(title: "Third", duration: 180))

        #expect(store.lectures.count == 3)
    }

    @Test @MainActor func updateLecture() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        var lecture = Lecture(title: "Original", duration: 60)
        store.addLecture(lecture)

        lecture.title = "Updated"
        store.updateLecture(lecture)

        #expect(store.lectures.first?.title == "Updated")
        #expect(store.lectures.count == 1)
    }

    @Test @MainActor func updateNonexistentLectureIsNoOp() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Existing", duration: 60))
        let nonexistent = Lecture(title: "Ghost", duration: 0)
        store.updateLecture(nonexistent) // Should not crash or change anything

        #expect(store.lectures.count == 1)
        #expect(store.lectures.first?.title == "Existing")
    }

    @Test @MainActor func deleteLecture() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        let lecture = Lecture(title: "To Delete", duration: 60)
        store.addLecture(lecture)
        #expect(store.lectures.count == 1)

        store.deleteLecture(lecture)
        #expect(store.lectures.isEmpty)
    }

    @Test @MainActor func deleteNonexistentLectureIsNoOp() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Keep", duration: 60))
        let ghost = Lecture(title: "Ghost", duration: 0)
        store.deleteLecture(ghost)

        #expect(store.lectures.count == 1)
    }

    @Test @MainActor func getLectureById() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        let lecture = Lecture(title: "Find Me", duration: 60)
        store.addLecture(lecture)

        let found = store.getLecture(by: lecture.id)
        #expect(found?.title == "Find Me")

        let notFound = store.getLecture(by: UUID())
        #expect(notFound == nil)
    }

    @Test @MainActor func persistenceRoundTrip() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Persisted", duration: 300))
        store.addLecture(Lecture(title: "Also Persisted", duration: 600))

        // Create a new store pointing to the same directory
        let store2 = TestableLectureStore(directory: dir)
        store2.loadLectures()

        #expect(store2.lectures.count == 2)
        #expect(store2.lectures.contains { $0.title == "Persisted" })
        #expect(store2.lectures.contains { $0.title == "Also Persisted" })
    }

    @Test @MainActor func loadFromBackupWhenPrimaryCorrupted() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Backed Up", duration: 100))
        store.saveToBackup()

        // Corrupt primary
        store.corruptPrimaryFile()

        // Load should fallback to backup
        let store2 = TestableLectureStore(directory: dir)
        store2.loadLectures()

        #expect(store2.lectures.count == 1)
        #expect(store2.lectures.first?.title == "Backed Up")
    }

    @Test @MainActor func loadFromBackupWhenPrimaryMissing() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Backup Only", duration: 100))
        store.saveToBackup()
        store.deletePrimaryFile()

        let store2 = TestableLectureStore(directory: dir)
        store2.loadLectures()

        #expect(store2.lectures.count == 1)
        #expect(store2.lectures.first?.title == "Backup Only")
    }

    @Test @MainActor func loadEmptyWhenNoFiles() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.loadLectures()
        #expect(store.lectures.isEmpty)
    }

    @Test @MainActor func searchByTitle() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Introduction to Physics", duration: 3600))
        store.addLecture(Lecture(title: "Chemistry Lab", duration: 1800))
        store.addLecture(Lecture(title: "Advanced Physics", duration: 2700))

        let results = store.searchLectures(query: "physics")
        #expect(results.count == 2)
    }

    @Test @MainActor func searchByTranscript() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Lecture 1", transcriptText: "The mitochondria is the powerhouse of the cell"))
        store.addLecture(Lecture(title: "Lecture 2", transcriptText: "Quantum mechanics introduction"))

        let results = store.searchLectures(query: "mitochondria")
        #expect(results.count == 1)
        #expect(results.first?.title == "Lecture 1")
    }

    @Test @MainActor func searchCaseInsensitive() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "UPPERCASE TITLE", duration: 60))
        let results = store.searchLectures(query: "uppercase")
        #expect(results.count == 1)
    }

    @Test @MainActor func searchEmptyQueryReturnsAll() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "A", duration: 60))
        store.addLecture(Lecture(title: "B", duration: 60))

        let results = store.searchLectures(query: "")
        #expect(results.count == 2)
    }

    @Test @MainActor func searchWhitespaceOnlyReturnsAll() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "A", duration: 60))
        let results = store.searchLectures(query: "   ")
        #expect(results.count == 1)
    }

    @Test @MainActor func searchNoResults() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "Math Class", duration: 60))
        let results = store.searchLectures(query: "quantum")
        #expect(results.isEmpty)
    }

    @Test @MainActor func allCourseNames() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "A", courseName: "CS101"))
        store.addLecture(Lecture(title: "B", courseName: "MATH200"))
        store.addLecture(Lecture(title: "C", courseName: "CS101")) // duplicate
        store.addLecture(Lecture(title: "D")) // no course

        let names = store.allCourseNames()
        #expect(names == ["CS101", "MATH200"]) // sorted, deduplicated
    }

    @Test @MainActor func allCourseNamesEmpty() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "No Course"))
        #expect(store.allCourseNames().isEmpty)
    }

    @Test @MainActor func deleteAllData() {
        let (store, dir) = makeTempStore()
        defer { cleanUp(dir) }

        store.addLecture(Lecture(title: "A", duration: 60))
        store.addLecture(Lecture(title: "B", duration: 120))
        #expect(store.lectures.count == 2)

        store.deleteAllData()
        #expect(store.lectures.isEmpty)
    }
}
