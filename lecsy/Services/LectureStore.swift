//
//  LectureStore.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import Combine

/// Lecture data management service
@MainActor
class LectureStore: ObservableObject {
    static let shared = LectureStore()
    
    @Published var lectures: [Lecture] = []
    
    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // Storage URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsPath.appendingPathComponent("lectures.json")
        
        // Date format settings
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Load data on launch
        loadLectures()
    }
    
    /// Add lecture
    func addLecture(_ lecture: Lecture) {
        lectures.append(lecture)
        saveLectures()
    }
    
    /// Update lecture
    func updateLecture(_ lecture: Lecture) {
        if let index = lectures.firstIndex(where: { $0.id == lecture.id }) {
            lectures[index] = lecture
            saveLectures()
        }
    }
    
    /// Delete lecture
    func deleteLecture(_ lecture: Lecture) {
        lectures.removeAll { $0.id == lecture.id }
        
        // Also delete audio file
        if let audioPath = lecture.audioPath {
            try? FileManager.default.removeItem(at: audioPath)
        }
        
        saveLectures()
    }
    
    /// Get lecture by ID
    func getLecture(by id: UUID) -> Lecture? {
        return lectures.first { $0.id == id }
    }
    
    /// Save lecture data
    func saveLectures() {
        do {
            let data = try encoder.encode(lectures)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save lectures: \(error)")
        }
    }
    
    /// Load lecture data
    func loadLectures() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            lectures = try decoder.decode([Lecture].self, from: data)
        } catch {
            print("Failed to load lectures: \(error)")
            lectures = []
        }
    }
    
    /// Mark as saved to Web
    func markAsSavedToWeb(_ lecture: Lecture, webId: UUID) {
        var updatedLecture = lecture
        updatedLecture.savedToWeb = true
        updatedLecture.webTranscriptId = webId
        updateLecture(updatedLecture)
    }
    
    /// Get lectures not saved to Web
    func getPendingUploads() -> [Lecture] {
        return lectures.filter { lecture in
            lecture.transcriptStatus == .completed &&
            !lecture.savedToWeb &&
            lecture.transcriptText != nil
        }
    }
    
    /// Search
    func searchLectures(query: String) -> [Lecture] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return lectures }
        
        let lowercasedQuery = trimmedQuery.lowercased()
        return lectures.filter { lecture in
            // Search by title
            lecture.displayTitle.lowercased().contains(lowercasedQuery) ||
            // Search by transcript text
            lecture.transcriptText?.lowercased().contains(lowercasedQuery) ?? false
        }
    }
    
    /// Delete all local data (for account deletion)
    func deleteAllData() {
        // Delete all audio files
        for lecture in lectures {
            if let audioPath = lecture.audioPath {
                try? FileManager.default.removeItem(at: audioPath)
            }
        }
        
        // Clear lectures array
        lectures = []
        
        // Delete storage file
        try? FileManager.default.removeItem(at: storageURL)
        
        // Save empty state
        saveLectures()
    }
}
