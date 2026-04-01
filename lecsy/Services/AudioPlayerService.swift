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

    static let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    private override init() {
        super.init()
    }

    /// Load an audio file for playback
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

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Audio file not found"
            case .loadFailed:
                return "Failed to load audio file"
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
