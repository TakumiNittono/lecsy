//
//  AudioPlayerService.swift
//  lecsy
//
//  Created on 2026/02/14.
//

import Foundation
import AVFoundation
import Combine

/// Audio playback service for playing recorded lectures
@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    /// `loadAsync` が AVAudioPlayer 失敗 → AVAssetExportSession で m4a を再 mux 修復
    /// しているフラグ。LectureDetailView 等が「Repairing audio…」を出すのに使う。
    /// 「音声は何があっても死守する」(memory: feedback_audio_must_survive.md) の
    /// 観点で、UI 上で何が起きているか黙らせず可視化する。
    @Published var isRepairing = false

    static let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    private override init() {
        super.init()
    }

    /// Load an audio file for playback (synchronous — kept for API compat).
    ///
    /// PERF WARNING: prefer `loadAsync(url:)` for UI call-sites. The
    /// underlying AVFoundation calls (`AVAudioSession.setActive`,
    /// `AVAudioPlayer(contentsOf:)`, `prepareToPlay`) each take tens to
    /// hundreds of ms on long files and block the main thread.
    func load(url: URL) throws {
        stop()

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlayerError.fileNotFound
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
        } catch {
            throw AudioPlayerError.loadFailed
        }
    }

    /// Async load — runs AVFoundation init off the main thread so the
    /// navigation push animation into LectureDetailView stays smooth even for
    /// 100-minute M4A files. The `@Published` updates happen back on main.
    ///
    /// 「音声は何があっても死守する」(memory: feedback_audio_must_survive.md):
    /// AVAudioPlayer init が落ちた場合 ── 多くは録音中の force-kill で moov atom が
    /// 書かれずに終わった m4a ── は AVAssetExportSession で再 mux 修復をかけて、
    /// 元ファイルを差し替えてから再試行する。失敗時の actual error は AppLogger に
    /// 残し、`.loadFailed(detail)` で呼び出し側に詳細を渡す。
    func loadAsync(url: URL) async throws {
        stop()

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlayerError.fileNotFound
        }

        do {
            try await openPlayer(url: url)
            return
        } catch {
            // 1段目失敗: 実 error をログに残してから修復を試みる。
            AppLogger.warning(
                "AVAudioPlayer init failed for \(url.lastPathComponent): \(error.localizedDescription) — attempting repair",
                category: .audio
            )

            isRepairing = true
            defer { isRepairing = false }

            do {
                let repairedURL = try await AudioFileRepairService.shared.repair(at: url)
                _ = try AudioFileRepairService.shared.replace(original: url, with: repairedURL)
                AppLogger.info("Audio repair succeeded for \(url.lastPathComponent)", category: .audio)
            } catch let repairError {
                AppLogger.error(
                    "Audio repair failed for \(url.lastPathComponent): \(repairError.localizedDescription)",
                    category: .audio
                )
                throw AudioPlayerError.loadFailedDetailed(repairError.localizedDescription)
            }

            // 修復後に再試行。ここで失敗したら諦める。
            do {
                try await openPlayer(url: url)
            } catch {
                AppLogger.error(
                    "AVAudioPlayer init failed even after repair: \(error.localizedDescription)",
                    category: .audio
                )
                throw AudioPlayerError.loadFailedDetailed(error.localizedDescription)
            }
        }
    }

    /// 実際に AVAudioPlayer を作って `audioPlayer` / `duration` を埋める部分。
    /// 修復前後で同じロジックを使うため private に切り出している。
    private func openPlayer(url: URL) async throws {
        let rate = playbackRate

        let prepared: (AVAudioPlayer, TimeInterval) = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.playback, mode: .default)
                    try audioSession.setActive(true)

                    let player = try AVAudioPlayer(contentsOf: url)
                    player.enableRate = true
                    player.rate = rate
                    player.prepareToPlay()
                    continuation.resume(returning: (player, player.duration))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        audioPlayer = prepared.0
        audioPlayer?.delegate = self
        duration = prepared.1
        currentTime = 0
    }

    /// Set playback rate
    func setRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
    }

    /// Cycle to next playback rate
    func cycleRate() {
        guard let currentIndex = Self.availableRates.firstIndex(of: playbackRate) else {
            setRate(1.0)
            return
        }
        let nextIndex = (currentIndex + 1) % Self.availableRates.count
        setRate(Self.availableRates[nextIndex])
    }

    /// Start or resume playback
    func play() {
        guard let player = audioPlayer else { return }
        player.rate = playbackRate
        player.play()
        isPlaying = true
        startTimer()
    }

    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    /// Stop playback and release resources
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Audio player error
    enum AudioPlayerError: LocalizedError {
        case fileNotFound
        case loadFailed
        /// 修復まで含めて失敗した時に actual error 文言を保持する。
        /// `.loadFailed` で詳細を握りつぶしていた旧挙動を置き換えるためのもの。
        case loadFailedDetailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Audio file not found"
            case .loadFailed:
                return "Failed to load audio file"
            case .loadFailedDetailed(let detail):
                return "Failed to load audio file: \(detail)"
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = duration // Stay at end position, not jump to 0
            stopTimer()
            // Deactivate session so other audio (music, etc.) can resume
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            AppLogger.error("Audio decode error: \(error?.localizedDescription ?? "Unknown error")", category: .audio)
            isPlaying = false
            stopTimer()
        }
    }
}
