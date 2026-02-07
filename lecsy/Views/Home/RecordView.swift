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
    @State private var showTranscriptionErrorAlert = false
    @State private var transcriptionErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // ストップウォッチ表示
            Text(formatDuration(recordingService.recordingDuration))
                .font(.system(size: 36, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.secondary)
            
            // Pause state display
            if recordingService.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.7))
            }
            
            // Record button and pause button
            HStack(spacing: 24) {
                // Pause/Resume button (only shown when recording)
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
                
                // Record start/stop button
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
        .alert("Microphone access permission required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
        .alert("Transcription Error", isPresented: $showTranscriptionErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(transcriptionErrorMessage)
        }
    }
    
    private func startRecording() {
        Task { @MainActor in
            print("🔴 Record button pressed")
            
            // Permission check
            var permissionStatus = AVAudioSession.sharedInstance().recordPermission
            print("🔴 Microphone permission status: \(permissionStatus.rawValue)")
            
            if permissionStatus == .undetermined {
                // Request permission if undetermined
                print("🔴 Requesting microphone permission")
                let granted = await recordingService.requestMicrophonePermission()
                print("🔴 Microphone permission request result: \(granted)")
                
                // Recheck permission status
                permissionStatus = AVAudioSession.sharedInstance().recordPermission
                print("🔴 Microphone permission status (recheck): \(permissionStatus.rawValue)")
                
                if !granted || permissionStatus != .granted {
                    permissionAlertMessage = "Microphone access has been denied. Please enable it in Settings."
                    showPermissionAlert = true
                    return
                }
            } else if permissionStatus != .granted {
                // Permission denied
                permissionAlertMessage = "Microphone access has been denied. Please enable it in Settings."
                showPermissionAlert = true
                return
            }
            
            // Start recording
            do {
                print("🔴 Starting recording")
                try await recordingService.startRecording()
                print("🔴 Recording started successfully: isRecording = \(recordingService.isRecording)")
            } catch {
                print("🔴 Recording start error: \(error)")
                permissionAlertMessage = "Failed to start recording: \(error.localizedDescription)"
                showPermissionAlert = true
            }
        }
    }
    
    private func stopRecording() {
        guard let audioURL = recordingService.stopRecording() else { return }
        
        // Create Lecture from recording data
        let lecture = Lecture(
            title: "",
            createdAt: Date(),
            duration: recordingService.recordingDuration,
            audioPath: audioURL,
            transcriptStatus: .notStarted
        )
        
        // Add to LectureStore
        let store = LectureStore.shared
        store.addLecture(lecture)
        
        // Start transcription
        Task {
            await startTranscription(for: lecture)
        }
    }
    
    private func startTranscription(for lecture: Lecture) async {
        guard let audioURL = lecture.audioPath else { return }
        
        let transcriptionService = TranscriptionService.shared
        
        // Update lecture status
        var updatedLecture = lecture
        updatedLecture.transcriptStatus = .processing
        LectureStore.shared.updateLecture(updatedLecture)
        
        do {
            // Execute transcription
            let result = try await transcriptionService.transcribe(audioURL: audioURL)
            
            // Save results
            updatedLecture.transcriptText = result.text
            updatedLecture.transcriptStatus = .completed
            // English-only: Always set to English
            updatedLecture.language = .english
            LectureStore.shared.updateLecture(updatedLecture)
        } catch {
            // Error handling
            updatedLecture.transcriptStatus = .failed
            LectureStore.shared.updateLecture(updatedLecture)
            print("Transcription failed: \(error)")
            
            // Show error alert to user
            await MainActor.run {
                transcriptionErrorMessage = error.localizedDescription
                showTranscriptionErrorAlert = true
            }
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
