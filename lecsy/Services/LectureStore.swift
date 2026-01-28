//
//  LectureStore.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import Combine

/// 講義データ管理サービス
@MainActor
class LectureStore: ObservableObject {
    static let shared = LectureStore()
    
    @Published var lectures: [Lecture] = []
    
    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // 保存先URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsPath.appendingPathComponent("lectures.json")
        
        // 日付フォーマット設定
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // 起動時にデータを読み込み
        loadLectures()
    }
    
    /// 講義を追加
    func addLecture(_ lecture: Lecture) {
        lectures.append(lecture)
        saveLectures()
    }
    
    /// 講義を更新
    func updateLecture(_ lecture: Lecture) {
        if let index = lectures.firstIndex(where: { $0.id == lecture.id }) {
            lectures[index] = lecture
            saveLectures()
        }
    }
    
    /// 講義を削除
    func deleteLecture(_ lecture: Lecture) {
        lectures.removeAll { $0.id == lecture.id }
        
        // 音声ファイルも削除
        if let audioPath = lecture.audioPath {
            try? FileManager.default.removeItem(at: audioPath)
        }
        
        saveLectures()
    }
    
    /// IDで講義を取得
    func getLecture(by id: UUID) -> Lecture? {
        return lectures.first { $0.id == id }
    }
    
    /// 講義データを保存
    func saveLectures() {
        do {
            let data = try encoder.encode(lectures)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save lectures: \(error)")
        }
    }
    
    /// 講義データを読み込み
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
    
    /// Webに保存済みとしてマーク
    func markAsSavedToWeb(_ lecture: Lecture, webId: UUID) {
        var updatedLecture = lecture
        updatedLecture.savedToWeb = true
        updatedLecture.webTranscriptId = webId
        updateLecture(updatedLecture)
    }
    
    /// Webに未保存の講義を取得
    func getPendingUploads() -> [Lecture] {
        return lectures.filter { lecture in
            lecture.transcriptStatus == .completed &&
            !lecture.savedToWeb &&
            lecture.transcriptText != nil
        }
    }
    
    /// 検索
    func searchLectures(query: String) -> [Lecture] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return lectures }
        
        let lowercasedQuery = trimmedQuery.lowercased()
        return lectures.filter { lecture in
            // タイトルで検索
            lecture.displayTitle.lowercased().contains(lowercasedQuery) ||
            // 文字起こしテキストで検索
            lecture.transcriptText?.lowercased().contains(lowercasedQuery) ?? false
        }
    }
}
