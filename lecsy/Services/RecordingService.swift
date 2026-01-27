//
//  RecordingService.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import AVFoundation
import Combine
import ActivityKit
import UIKit

/// 録音サービス
@MainActor
class RecordingService: NSObject, ObservableObject {
    static let shared = RecordingService()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingStartTime: Date?
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var backgroundTaskTimer: Timer?
    private var recordingURL: URL?
    private var liveActivity: Activity<LecsyWidgetAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var currentLectureTitle: String = "New Recording"
    
    // 100分（6000秒）の録音に対応
    private let maxRecordingDuration: TimeInterval = 6000 // 100分
    
    private override init() {
        super.init()
    }
    
    /// マイク権限をリクエスト
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// 録音開始
    func startRecording(lectureTitle: String = "New Recording") throws {
        print("🔴 RecordingService.startRecording() が呼ばれました")
        
        guard !isRecording else {
            print("🔴 既に録音中です")
            return
        }
        
        // マイク権限チェック
        let hasPermission = AVAudioSession.sharedInstance().recordPermission
        print("🔴 マイク権限状態: \(hasPermission.rawValue)")
        guard hasPermission == .granted else {
            print("🔴 マイク権限がありません")
            throw RecordingError.permissionDenied
        }
        
        // ディスク容量チェック（100分の録音には約50-100MB必要）
        let requiredSpace: Int64 = 100 * 1024 * 1024 // 100MB
        if let availableSpace = getAvailableDiskSpace(), availableSpace < requiredSpace {
            print("🔴 ディスク容量不足: 利用可能 \(availableSpace / 1024 / 1024)MB, 必要 \(requiredSpace / 1024 / 1024)MB")
            throw RecordingError.insufficientStorage
        }
        
        // オーディオセッション設定（バックグラウンド録音対応）
        print("🔴 オーディオセッションを設定します")
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // バックグラウンド録音に最適化された設定
            // .allowBluetoothA2DPは削除（録音には不要で、エラーの原因になる可能性がある）
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            
            // バックグラウンド録音を有効化
            try audioSession.setActive(true, options: [])
            
            // バックグラウンド録音が有効か確認
            if !audioSession.isOtherAudioPlaying {
                print("🔴 オーディオセッション設定成功（バックグラウンド録音有効）")
            } else {
                print("⚠️ 他のオーディオが再生中です")
            }
        } catch {
            print("🔴 オーディオセッション設定エラー: \(error)")
            throw RecordingError.recordingFailed
        }
        
        // バックグラウンドタスク開始
        setupBackgroundTask()
        
        // 録音ファイルのURL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            print("🔴 録音ファイルURLの作成に失敗")
            throw RecordingError.fileCreationFailed
        }
        
        print("🔴 録音ファイルURL: \(url)")
        
        // 録音設定（長時間録音に最適化：品質とファイルサイズのバランス）
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue, // 長時間録音のためmediumに変更
            AVEncoderBitRateKey: 64000 // 64kbps（100分で約50MB）
        ]
        
        // 録音開始
        print("🔴 AVAudioRecorderを作成します")
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            
            let recordingStarted = audioRecorder?.record() ?? false
            print("🔴 録音開始: \(recordingStarted)")
            
            if !recordingStarted {
                print("🔴 録音開始に失敗しました")
                throw RecordingError.recordingFailed
            }
        } catch {
            print("🔴 AVAudioRecorder作成/開始エラー: \(error)")
            throw RecordingError.recordingFailed
        }
        
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0
        currentLectureTitle = lectureTitle
        
        print("🔴 録音状態を更新: isRecording = \(isRecording)")
        
        // Live Activity開始
        startLiveActivity()
        
        // タイマー開始（1秒ごとに更新、Live Activityも1秒ごとに更新）
        // バックグラウンドでも動作するようにRunLoopに追加
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let startTime = self.recordingStartTime else {
                timer.invalidate()
                return
            }
            self.recordingDuration = Date().timeIntervalSince(startTime)
            
            // 最大録音時間チェック
            if self.recordingDuration >= self.maxRecordingDuration {
                print("🔴 最大録音時間に達しました（100分）")
                _ = self.stopRecording()
                return
            }
            
            // 録音が継続しているか確認（ロック画面時など）
            if let recorder = self.audioRecorder, !recorder.isRecording {
                print("⚠️ 録音が停止しています。再開を試みます...")
                // 録音を再開
                recorder.record()
            }
            
            // Live Activityを1秒ごとに更新（ロック画面のストップウォッチを滑らかに動かすため）
            self.updateLiveActivity()
        }
        
        // バックグラウンドでもタイマーが動作するようにRunLoopに追加
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        // バックグラウンドタスクの定期更新（30秒ごと）
        setupBackgroundTaskRenewal()
        
        print("🔴 タイマー開始完了")
    }
    
    /// 録音停止
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        
        isRecording = false
        
        // Live Activity終了
        endLiveActivity()
        
        // バックグラウンドタスク終了
        endBackgroundTask()
        
        let url = recordingURL
        recordingURL = nil
        recordingStartTime = nil
        
        // オーディオセッションを非アクティブに
        try? AVAudioSession.sharedInstance().setActive(false)
        
        return url
    }
    
    // MARK: - Disk Space Management
    
    /// 利用可能なディスク容量を取得（バイト単位）
    private func getAvailableDiskSpace() -> Int64? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                return freeSpace
            }
        } catch {
            print("🔴 ディスク容量取得エラー: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Background Task Management
    
    /// バックグラウンドタスクの定期更新（長時間録音対応）
    private func setupBackgroundTaskRenewal() {
        // 30秒ごとにバックグラウンドタスクを更新
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else {
                return
            }
            
            // 既存のタスクを終了
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
            }
            
            // 新しいタスクを開始
            self.setupBackgroundTask()
            
            print("🔴 バックグラウンドタスクを更新しました")
        }
    }
    
    // MARK: - Live Activities
    
    /// Live Activityを開始
    private func startLiveActivity() {
        // ActivityKitが利用可能かチェック
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = LecsyWidgetAttributes(lectureTitle: currentLectureTitle)
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: 0,
            isRecording: true
        )
        
        do {
            liveActivity = try Activity<LecsyWidgetAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    /// Live Activityを更新
    private func updateLiveActivity() {
        guard let liveActivity = liveActivity else { return }
        
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: recordingDuration,
            isRecording: isRecording
        )
        
        // 非同期で更新（メインスレッドで実行）
        // 1秒ごとの更新でロック画面のストップウォッチを滑らかに動かす
        Task { @MainActor in
            do {
                // 数値の変化を滑らかにアニメーション
                var updateConfig = Activity<LecsyWidgetAttributes>.UpdateConfiguration()
                updateConfig.alertConfiguration = nil
                
                await liveActivity.update(
                    using: contentState,
                    alertConfiguration: nil
                )
            } catch {
                // エラーが頻繁に発生する場合は、更新頻度を下げる
                print("⚠️ Live Activity更新エラー: \(error)")
            }
        }
    }
    
    /// Live Activityを終了
    private func endLiveActivity() {
        guard let liveActivity = liveActivity else { return }
        
        let contentState = LecsyWidgetAttributes.ContentState(
            recordingDuration: recordingDuration,
            isRecording: false
        )
        
        Task {
            await liveActivity.end(using: contentState, dismissalPolicy: .immediate)
        }
        
        self.liveActivity = nil
    }
    
    // MARK: - Background Task
    
    /// バックグラウンドタスクを開始
    private func setupBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    /// バックグラウンドタスクを終了
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    /// 録音エラー
    enum RecordingError: LocalizedError {
        case permissionDenied
        case fileCreationFailed
        case recordingFailed
        case insufficientStorage
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission is required"
            case .fileCreationFailed:
                return "Failed to create recording file"
            case .recordingFailed:
                return "Recording failed"
            case .insufficientStorage:
                return "Insufficient storage space. Please free up at least 100MB."
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                isRecording = false
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("🔴 録音エンコードエラー: \(error?.localizedDescription ?? "Unknown")")
            isRecording = false
            timer?.invalidate()
            timer = nil
            backgroundTaskTimer?.invalidate()
            backgroundTaskTimer = nil
            endLiveActivity()
            endBackgroundTask()
        }
    }
    
    nonisolated func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        Task { @MainActor in
            print("🔴 録音が中断されました（電話など）")
            // 中断時は録音を継続（iOSが自動的に処理）
        }
    }
    
    nonisolated func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        Task { @MainActor in
            print("🔴 録音中断が終了しました")
            // 録音を再開（必要に応じて）
            if isRecording {
                audioRecorder?.record()
            }
        }
    }
}
