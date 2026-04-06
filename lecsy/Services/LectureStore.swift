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
    private let backupStorageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // Storage URL
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            preconditionFailure("Documents directory not found")
        }
        storageURL = documentsPath.appendingPathComponent("lectures.json")
        backupStorageURL = documentsPath.appendingPathComponent("lectures_backup.json")
        
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
    
    /// Update lecture (writes to disk first, then updates in-memory state)
    func updateLecture(_ lecture: Lecture) {
        guard let index = lectures.firstIndex(where: { $0.id == lecture.id }) else { return }
        let previous = lectures[index]
        lectures[index] = lecture
        let saved = saveLecturesReturningSuccess()
        if !saved {
            // Rollback in-memory state if disk write failed
            lectures[index] = previous
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
    
    /// Save lecture data and return whether the write succeeded
    @discardableResult
    private func saveLecturesReturningSuccess() -> Bool {
        do {
            let data = try encoder.encode(lectures)
            let tempURL = storageURL.deletingLastPathComponent()
                .appendingPathComponent("lectures_temp_\(UUID().uuidString).json")
            do {
                try data.write(to: tempURL, options: .atomic)
                _ = try FileManager.default.replaceItemAt(storageURL, withItemAt: tempURL)
                return true
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                AppLogger.error("Failed to save lectures to primary location: \(error)", category: .storage)
                do {
                    try data.write(to: backupStorageURL, options: .atomic)
                    AppLogger.warning("Lectures saved to backup location: \(backupStorageURL.path)", category: .storage)
                    return true
                } catch {
                    AppLogger.error("Failed to save lectures to backup location: \(error). Data may be out of sync with disk.", category: .storage)
                    return false
                }
            }
        } catch {
            AppLogger.error("Failed to encode lectures: \(error)", category: .storage)
            return false
        }
    }

    /// Save lecture data (atomic write to prevent corruption)
    func saveLectures() {
        do {
            let data = try encoder.encode(lectures)

            // Write to a temporary file first, then atomically move into place.
            // This prevents corruption if the app crashes mid-write.
            let tempURL = storageURL.deletingLastPathComponent()
                .appendingPathComponent("lectures_temp_\(UUID().uuidString).json")
            do {
                try data.write(to: tempURL, options: .atomic)
                // Atomic move: replace the primary file only after temp is fully written
                _ = try FileManager.default.replaceItemAt(storageURL, withItemAt: tempURL)
            } catch {
                // Clean up temp file if it exists
                try? FileManager.default.removeItem(at: tempURL)
                AppLogger.error("Failed to save lectures to primary location: \(error)", category: .storage)
                // Attempt direct write to backup location
                do {
                    try data.write(to: backupStorageURL, options: .atomic)
                    AppLogger.warning("Lectures saved to backup location: \(backupStorageURL.path)", category: .storage)
                } catch {
                    AppLogger.error("Failed to save lectures to backup location: \(error). Data may be out of sync with disk.", category: .storage)
                }
            }
        } catch {
            AppLogger.error("Failed to encode lectures: \(error)", category: .storage)
        }
    }
    
    /// Load lecture data (falls back to backup if primary is corrupted)
    func loadLectures() {
        // Try primary location first
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                lectures = try decoder.decode([Lecture].self, from: data)
                return
            } catch {
                AppLogger.error("Failed to load lectures from primary: \(error)", category: .storage)
            }
        }

        // Fall back to backup location
        if FileManager.default.fileExists(atPath: backupStorageURL.path) {
            do {
                let data = try Data(contentsOf: backupStorageURL)
                lectures = try decoder.decode([Lecture].self, from: data)
                AppLogger.warning("Loaded lectures from backup location", category: .storage)
                // Restore primary from backup
                saveLectures()
                return
            } catch {
                AppLogger.error("Failed to load lectures from backup: \(error)", category: .storage)
            }
        }

        lectures = []
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
    
    /// Get all unique course names
    func allCourseNames() -> [String] {
        Array(Set(lectures.compactMap { $0.courseName })).sorted()
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
