//
//  RecordView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI
import AVFoundation

struct RecordView: View {
    @StateObject private var recordingService = RecordingService.shared
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // ストップウォッチ表示
            Text(formatDuration(recordingService.recordingDuration))
                .font(.system(size: 36, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.secondary)
            
            // ポーズ状態の表示
            if recordingService.isPaused {
                Text("一時停止中")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.7))
            }
            
            // 録音ボタンとポーズボタン
            HStack(spacing: 24) {
                // ポーズ/再開ボタン（録音中のみ表示）
                if recordingService.isRecording {
                    Button(action: {
                        if recordingService.isPaused {
                            recordingService.resumeRecording()
                        } else {
                            recordingService.pauseRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.8))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: recordingService.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // 録音開始/停止ボタン
                Button(action: {
                    if recordingService.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(recordingService.isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.7))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: recordingService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .alert("マイクへのアクセス権限が必要です", isPresented: $showPermissionAlert) {
            Button("設定") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    private func startRecording() {
        Task { @MainActor in
            print("🔴 録音開始ボタンが押されました")
            
            // 権限チェック
            var permissionStatus = AVAudioSession.sharedInstance().recordPermission
            print("🔴 マイク権限状態: \(permissionStatus.rawValue)")
            
            if permissionStatus == .undetermined {
                // 権限が未確定の場合はリクエスト
                print("🔴 マイク権限をリクエストします")
                let granted = await recordingService.requestMicrophonePermission()
                print("🔴 マイク権限リクエスト結果: \(granted)")
                
                // 権限状態を再確認
                permissionStatus = AVAudioSession.sharedInstance().recordPermission
                print("🔴 マイク権限状態（再確認）: \(permissionStatus.rawValue)")
                
                if !granted || permissionStatus != .granted {
                    permissionAlertMessage = "マイクへのアクセスが拒否されています。設定アプリから権限を有効にしてください。"
                    showPermissionAlert = true
                    return
                }
            } else if permissionStatus != .granted {
                // 権限が拒否されている場合
                permissionAlertMessage = "マイクへのアクセスが拒否されています。設定アプリから権限を有効にしてください。"
                showPermissionAlert = true
                return
            }
            
            // 権限が許可されている場合、録音を開始
            do {
                print("🔴 録音を開始します")
                try await recordingService.startRecording()
                print("🔴 録音開始成功: isRecording = \(recordingService.isRecording)")
            } catch {
                print("🔴 録音開始エラー: \(error)")
                permissionAlertMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
                showPermissionAlert = true
            }
        }
    }
    
    private func stopRecording() {
        guard let audioURL = recordingService.stopRecording() else { return }
        
        // 録音データからLectureを作成
        let lecture = Lecture(
            title: "",
            createdAt: Date(),
            duration: recordingService.recordingDuration,
            audioPath: audioURL,
            transcriptStatus: .notStarted
        )
        
        // LectureStoreに追加
        let store = LectureStore.shared
        store.addLecture(lecture)
        
        // 文字起こしを開始
        Task {
            await startTranscription(for: lecture)
        }
    }
    
    private func startTranscription(for lecture: Lecture) async {
        guard let audioURL = lecture.audioPath else { return }
        
        let transcriptionService = TranscriptionService.shared
        
        // 講義の状態を更新
        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        LectureStore.shared.updateLecture(updatedLecture)
        
        do {
            // 文字起こし実行
            let result = try await transcriptionService.transcribe(audioURL: audioURL)
            
            // 結果を保存
            updatedLecture.transcriptText = result.text
            updatedLecture.transcriptStatus = .completed
            updatedLecture.language = TranscriptionLanguage(rawValue: result.language ?? "auto") ?? .auto
            LectureStore.shared.updateLecture(updatedLecture)
        } catch {
            // エラー処理
            updatedLecture.transcriptStatus = .failed
            LectureStore.shared.updateLecture(updatedLecture)
            print("Transcription failed: \(error)")
        }
    }
    
    private func hasMicrophonePermission() -> Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    RecordView()
}
