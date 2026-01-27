//
//  LectureDetailView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI

struct LectureDetailView: View {
    @StateObject private var store = LectureStore.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var authService = AuthService.shared
    @State private var title: String
    @State private var lecture: Lecture
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSavingToWeb = false
    
    init(lecture: Lecture) {
        _lecture = State(initialValue: lecture)
        _title = State(initialValue: lecture.title)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // タイトル編集
                TextField("Title", text: $title)
                    .font(.title2)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: title) { oldValue, newValue in
                        var updatedLecture = lecture
                        updatedLecture.title = newValue
                        store.updateLecture(updatedLecture)
                        lecture = updatedLecture
                    }
                
                // メタ情報
                HStack {
                    Label(lecture.formattedDuration, systemImage: "clock")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(lecture.createdAt, style: .date)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Divider()
                
                // コピーボタンとWeb保存ボタン（文字起こしがある場合）
                if let transcript = lecture.transcriptText, !transcript.isEmpty {
                    HStack(spacing: 16) {
                        CopyButton(text: transcript)
                        
                        if !lecture.savedToWeb {
                            Button(action: {
                                Task {
                                    isSavingToWeb = true
                                    do {
                                        _ = try await syncService.saveToWeb(lecture: lecture)
                                        // 最新の状態を取得
                                        if let updatedLecture = store.getLecture(by: lecture.id) {
                                            lecture = updatedLecture
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                    isSavingToWeb = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if isSavingToWeb {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "icloud.and.arrow.up")
                                    }
                                    Text(isSavingToWeb ? "Saving..." : "Save to Web")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                            .disabled(isSavingToWeb || !authService.isAuthenticated)
                        } else {
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.icloud")
                                    Text("Saved to Web")
                                }
                                .font(.subheadline)
                                .foregroundColor(.green)
                                
                                // Open on Webボタン
                                if let webId = lecture.webTranscriptId {
                                    Button(action: {
                                        let webURL = URL(string: "https://lecsy.vercel.app/app/t/\(webId.uuidString)")!
                                        UIApplication.shared.open(webURL)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "safari")
                                            Text("Open on Web")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                
                // 文字起こしテキスト
                if lecture.transcriptStatus == .processing {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if let transcript = lecture.transcriptText {
                    Text(transcript)
                        .font(.body)
                } else if lecture.transcriptStatus == .failed {
                    Text("Transcription failed")
                        .font(.body)
                        .foregroundColor(.red)
                } else {
                    Text("No transcript available")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Lecture")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save to Web Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    NavigationView {
        LectureDetailView(lecture: Lecture(
            title: "Sample Lecture",
            createdAt: Date(),
            duration: 3600,
            transcriptText: "This is a sample transcript text."
        ))
    }
}
