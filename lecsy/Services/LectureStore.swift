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

    /// UI に出る lectures (ユーザーごとにフィルタ済)。
    /// - 現在サインインしているユーザーの録音 (ownerUserID == currentUser.id)
    /// - 匿名 or legacy 録音 (ownerUserID == nil)
    /// の合算。端末共有時に前ユーザーの録音が次ユーザーに漏れないようにするため。
    /// 実ストレージは `allLectures` に保持しており、ユーザー切替 (sign-in/out) 時に
    /// `republishForCurrentUser()` で再計算される。
    @Published private(set) var lectures: [Lecture] = []

    /// ディスクに保存されているすべての録音 (全ユーザー分)。UI からは直接読まない。
    private var allLectures: [Lecture] = []

    /// サインイン/サインアウト購読用。AuthService.currentUser が変わる度に
    /// lectures (public) を再計算する。
    private var authCancellable: AnyCancellable?

    private let storageURL: URL
    private let backupStorageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Apply file protection (completeUntilFirstUserAuth — safe for background recording)
    /// and exclude from iCloud/iTunes backup. Best-effort; failures are non-fatal.
    private func applyProtectionAndBackupExclusion(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        var u = url
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? u.setResourceValues(rv)
    }
    
    private init() {
        // Storage URL.
        // On iOS the Documents directory is guaranteed to exist, but we
        // fall back to the app's tmp directory instead of crashing on
        // launch if something truly bizarre happens. Crashing 500
        // production users at startup would be worse than degraded mode.
        let documentsPath = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        storageURL = documentsPath.appendingPathComponent("lectures.json")
        backupStorageURL = documentsPath.appendingPathComponent("lectures_backup.json")

        // Date format settings
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // Load data on launch
        loadLectures()

        // Auth state を監視して、サインイン/サインアウト時に published lectures を
        // 再計算する。端末共有時に前ユーザーの録音が次ユーザーに見えるのを防ぐ。
        authCancellable = AuthService.shared.$currentUser
            .removeDuplicates(by: { $0?.id == $1?.id })
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.republishForCurrentUser()
                }
            }
    }

    /// 現在サインインしているユーザーのスコープに合わせて `lectures` (public) を再計算する。
    /// allLectures から (ownerUserID == currentUserID) または (ownerUserID == nil) の
    /// lecture だけを抽出する。
    private func republishForCurrentUser() {
        let currentUserID = AuthService.shared.currentUser?.id
        lectures = allLectures.filter { lecture in
            lecture.ownerUserID == currentUserID || lecture.ownerUserID == nil
        }
    }

    /// Add lecture (tag with current user automatically)
    func addLecture(_ lecture: Lecture) {
        var tagged = lecture
        if tagged.ownerUserID == nil {
            tagged.ownerUserID = AuthService.shared.currentUser?.id
        }
        allLectures.append(tagged)
        republishForCurrentUser()
        saveLectures()
    }

    /// Update lecture (writes to disk first, then updates in-memory state)
    func updateLecture(_ lecture: Lecture) {
        guard let index = allLectures.firstIndex(where: { $0.id == lecture.id }) else { return }
        let previous = allLectures[index]
        // ownerUserID は保存時点で確定した値を尊重 (UI 側の書き換えでは変えない)
        var merged = lecture
        merged.ownerUserID = previous.ownerUserID
        allLectures[index] = merged
        republishForCurrentUser()
        let saved = saveLecturesReturningSuccess()
        if !saved {
            // Rollback in-memory state if disk write failed
            allLectures[index] = previous
            republishForCurrentUser()
        }
    }

    /// Delete lecture
    func deleteLecture(_ lecture: Lecture) {
        allLectures.removeAll { $0.id == lecture.id }
        republishForCurrentUser()

        // Also delete audio file
        if let audioPath = lecture.audioPath {
            try? FileManager.default.removeItem(at: audioPath)
        }

        saveLectures()
    }

    /// Soft-delete for the Library's undo flow: drop the lecture from the
    /// published list + disk but keep the audio file intact so `addLecture`
    /// can re-insert it if the user taps Undo. The caller (LibraryView)
    /// removes the audio file only after the undo window elapses.
    func softDeleteLecture(_ lecture: Lecture) {
        allLectures.removeAll { $0.id == lecture.id }
        republishForCurrentUser()
        saveLectures()
    }

    /// Get lecture by ID (scoped to currently-visible lectures; call sites that
    /// need cross-user access should be reviewed carefully — there are none today).
    func getLecture(by id: UUID) -> Lecture? {
        return lectures.first { $0.id == id }
    }
    
    /// Save lecture data and return whether the write succeeded
    @discardableResult
    private func saveLecturesReturningSuccess() -> Bool {
        do {
            let data = try encoder.encode(allLectures)
            let tempURL = storageURL.deletingLastPathComponent()
                .appendingPathComponent("lectures_temp_\(UUID().uuidString).json")
            do {
                try data.write(to: tempURL, options: .atomic)
                _ = try FileManager.default.replaceItemAt(storageURL, withItemAt: tempURL)
                applyProtectionAndBackupExclusion(storageURL)
                return true
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                AppLogger.error("Failed to save lectures to primary location: \(error)", category: .storage)
                do {
                    try data.write(to: backupStorageURL, options: .atomic)
                    applyProtectionAndBackupExclusion(backupStorageURL)
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

    /// Save lecture data (atomic write to prevent corruption).
    ///
    /// Snapshots the in-memory `lectures` on the main actor, then hands encode
    /// + disk write off to a detached background task so large libraries don't
    /// block the UI thread. This is fire-and-forget; callers that need to know
    /// whether the write succeeded (e.g. `updateLecture` rollback path) must
    /// use `saveLecturesReturningSuccess()` instead, which remains synchronous.
    func saveLectures() {
        let snapshot = allLectures
        let storageURL = self.storageURL
        let backupStorageURL = self.backupStorageURL
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(snapshot)

                // Write to a temporary file first, then atomically move into place.
                // This prevents corruption if the app crashes mid-write.
                let tempURL = storageURL.deletingLastPathComponent()
                    .appendingPathComponent("lectures_temp_\(UUID().uuidString).json")
                do {
                    try data.write(to: tempURL, options: .atomic)
                    // Atomic move: replace the primary file only after temp is fully written
                    _ = try FileManager.default.replaceItemAt(storageURL, withItemAt: tempURL)
                    await MainActor.run { [weak self] in
                        self?.applyProtectionAndBackupExclusion(storageURL)
                    }
                } catch {
                    // Clean up temp file if it exists
                    try? FileManager.default.removeItem(at: tempURL)
                    AppLogger.error("Failed to save lectures to primary location: \(error)", category: .storage)
                    // Attempt direct write to backup location
                    do {
                        try data.write(to: backupStorageURL, options: .atomic)
                        await MainActor.run { [weak self] in
                            self?.applyProtectionAndBackupExclusion(backupStorageURL)
                        }
                        AppLogger.warning("Lectures saved to backup location: \(backupStorageURL.path)", category: .storage)
                    } catch {
                        AppLogger.error("Failed to save lectures to backup location: \(error). Data may be out of sync with disk.", category: .storage)
                    }
                }
            } catch {
                AppLogger.error("Failed to encode lectures: \(error)", category: .storage)
            }
        }
    }
    
    /// Load lecture data (falls back to backup if primary is corrupted)
    func loadLectures() {
        // Try primary location first
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                allLectures = try decoder.decode([Lecture].self, from: data)
                republishForCurrentUser()
                return
            } catch {
                AppLogger.error("Failed to load lectures from primary: \(error)", category: .storage)
            }
        }

        // Fall back to backup location
        if FileManager.default.fileExists(atPath: backupStorageURL.path) {
            do {
                let data = try Data(contentsOf: backupStorageURL)
                allLectures = try decoder.decode([Lecture].self, from: data)
                republishForCurrentUser()
                AppLogger.warning("Loaded lectures from backup location", category: .storage)
                // Restore primary from backup
                saveLectures()
                return
            } catch {
                AppLogger.error("Failed to load lectures from backup: \(error)", category: .storage)
            }
        }

        allLectures = []
        republishForCurrentUser()
    }
    
    /// Search (scoped to the currently signed-in user's visible lectures)
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

    /// Get all unique course names (scoped to the currently signed-in user)
    func allCourseNames() -> [String] {
        Array(Set(lectures.compactMap { $0.courseName })).sorted()
    }

    /// Delete all local data (for account deletion / "Sign Out & Delete Data" flow).
    /// ユーザーが明示的に選択するルートなので全録音を対象にする (他ユーザー分も含む)。
    func deleteAllData() {
        // Delete all audio files
        for lecture in allLectures {
            if let audioPath = lecture.audioPath {
                try? FileManager.default.removeItem(at: audioPath)
            }
        }

        allLectures = []
        republishForCurrentUser()

        // Delete storage file
        try? FileManager.default.removeItem(at: storageURL)

        // Save empty state
        saveLectures()
    }
}
