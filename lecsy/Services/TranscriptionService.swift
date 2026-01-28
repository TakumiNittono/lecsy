//
//  TranscriptionService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import WhisperKit
import AVFoundation
import Combine

/// 文字起こしサービス
@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    @Published var state: TranscriptionState = .idle
    @Published var progress: Double = 0
    @Published var transcriptionLanguage: TranscriptionLanguage = .auto
    @Published var isModelLoaded: Bool = false
    @Published var modelDownloadProgress: Double = 0
    
    private var whisperKit: WhisperKit?
    private var transcriptionTask: Task<Void, Never>?
    private var currentLanguageCode: String? // 現在設定されている言語コード
    
    private init() {
        // 保存された言語設定を読み込み
        if let savedLanguageRaw = UserDefaults.standard.string(forKey: "transcriptionLanguage"),
           let savedLanguage = TranscriptionLanguage(rawValue: savedLanguageRaw) {
            transcriptionLanguage = savedLanguage
            currentLanguageCode = savedLanguage.whisperLanguage
            print("🔵 保存された言語設定を読み込み: \(savedLanguage.displayName) (\(savedLanguage.rawValue))")
        } else {
            // デフォルトは日本語
            transcriptionLanguage = .japanese
            currentLanguageCode = "ja"
            UserDefaults.standard.set(TranscriptionLanguage.japanese.rawValue, forKey: "transcriptionLanguage")
            print("🔵 デフォルト言語を日本語に設定")
        }
    }
    
    /// 言語設定を変更して保存
    func setLanguage(_ language: TranscriptionLanguage) {
        transcriptionLanguage = language
        currentLanguageCode = language.whisperLanguage
        UserDefaults.standard.set(language.rawValue, forKey: "transcriptionLanguage")
        
        // 言語が変更された場合、モデルを再読み込みする必要がある可能性があるため、whisperKitをnilにリセット
        whisperKit = nil
        isModelLoaded = false
        
        print("🔵 言語設定を変更: \(language.displayName) (\(language.rawValue))")
        if let langCode = currentLanguageCode {
            print("🔵 言語コード: \(langCode)")
        } else {
            print("🔵 自動検出モード")
        }
    }
    
    /// モデルがダウンロード済みか確認
    func isModelDownloaded() -> Bool {
        // WhisperKitのモデルキャッシュディレクトリを確認
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = cacheDir.appendingPathComponent("WhisperKit")
        let modelPath = modelDir.appendingPathComponent("openai_whisper-coreml-base")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// モデルを読み込む
    func loadModel() async throws {
        guard !isModelLoaded else { return }
        
        state = .downloading
        progress = 0
        
        do {
            // WhisperKitを初期化（モデルを自動ダウンロード）
            // baseモデルを使用（約500MB、高速）
            print("🔵 WhisperKitモデルを読み込みます: 言語設定 = \(transcriptionLanguage.displayName)")
            
            // WhisperKitを初期化（シンプルな初期化）
            whisperKit = try await WhisperKit()
            
            isModelLoaded = true
            state = .idle
            progress = 1.0
            print("🔵 WhisperKitモデルの読み込み完了")
        } catch {
            state = .failed
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    /// 文字起こしを実行
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // モデルが読み込まれていない場合は自動的に読み込む
        if whisperKit == nil {
            try await loadModel()
        }
        
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        state = .processing
        progress = 0
        
        do {
            // 設定された言語をログに記録
            print("🔵 文字起こし開始: 言語設定 = \(transcriptionLanguage.displayName) (\(transcriptionLanguage.rawValue))")
            
            // DecodingOptionsで言語を指定
            var decodeOptions = DecodingOptions()
            
            if let languageCode = currentLanguageCode {
                // 言語を明示的に指定（日本語の場合は確実に日本語として処理）
                decodeOptions.language = languageCode
                decodeOptions.usePrefillPrompt = true // 言語を強制指定するために必要
                decodeOptions.detectLanguage = false // 言語検出を無効化して指定した言語を使用
                print("🔵 言語を強制指定: \(languageCode)")
            } else {
                // 自動検出モード
                decodeOptions.detectLanguage = true
                print("🔵 自動検出モード")
            }
            
            // 文字起こし実行（WhisperKitが音声ファイルを直接処理）
            // WhisperKitのtranscribeメソッドは[TranscriptionResult]を返す
            let whisperResults = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: decodeOptions
            )
            
            print("🔵 WhisperKitが検出した言語: \(whisperResults.first?.language ?? "不明")")
            
            // 設定された言語と検出された言語が一致するか確認
            if let detectedLanguage = whisperResults.first?.language,
               let languageCode = currentLanguageCode,
               detectedLanguage != languageCode {
                print("⚠️ 警告: 設定された言語(\(languageCode))と検出された言語(\(detectedLanguage))が一致しません")
            }
            
            // 配列から最初の結果を取得
            guard let whisperResult = whisperResults.first else {
                throw TranscriptionError.transcriptionFailed
            }
            
            // 結果を変換（WhisperKitのTranscriptionResultから独自のTranscriptionResultへ）
            // 名前空間を明確にするため、型エイリアスを使用
            typealias LectureTranscriptionResult = TranscriptionResult
            typealias LectureTranscriptionSegment = LectureTranscriptionResult.TranscriptionSegment
            
            // WhisperKitのsegmentsはFloat型のstart/endを持つため、Doubleに変換
            let segments = whisperResult.segments.map { segment in
                LectureTranscriptionSegment(
                    startTime: Double(segment.start),
                    endTime: Double(segment.end),
                    text: segment.text
                )
            }
            
            let fullText = whisperResult.text
            
            state = .completed
            progress = 1.0
            
            // processingTimeプロパティが存在しない可能性があるため、デフォルト値を使用
            // WhisperKitのTranscriptionResultにはprocessingTimeプロパティがない可能性がある
            let processingTime: TimeInterval = 0.0
            
            return LectureTranscriptionResult(
                text: fullText,
                segments: segments,
                language: whisperResult.language,
                processingTime: processingTime
            )
        } catch {
            state = .failed
            throw error
        }
    }
    
    /// 文字起こしをキャンセル
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        state = .idle
        progress = 0
    }
    
    /// モデルを削除
    func deleteModel() throws {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = cacheDir.appendingPathComponent("WhisperKit")
        
        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
        }
        
        whisperKit = nil
        isModelLoaded = false
    }
    
    /// モデルサイズを取得（バイト単位）
    var modelSize: Int64 {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = cacheDir.appendingPathComponent("WhisperKit")
        
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: modelDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
}

/// 文字起こし状態
enum TranscriptionState {
    case idle
    case downloading
    case processing
    case completed
    case failed
}

/// 文字起こしエラー
enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case audioLoadFailed
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "モデルが読み込まれていません"
        case .modelLoadFailed(let message):
            return "モデルの読み込みに失敗しました: \(message)"
        case .audioLoadFailed:
            return "音声ファイルの読み込みに失敗しました"
        case .transcriptionFailed:
            return "文字起こしに失敗しました"
        }
    }
}
