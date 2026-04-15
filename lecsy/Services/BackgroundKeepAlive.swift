//
//  BackgroundKeepAlive.swift
//  lecsy
//
//  Keeps the app running in the background during long transcription jobs
//  by playing a silent audio loop on an active AVAudioSession. iOS grants
//  continuous background execution to apps with the "audio" background mode
//  as long as an audio session is active — this is the standard technique
//  used by podcast / transcription apps to finish user-initiated work that
//  would otherwise be killed by the system after ~30 seconds.
//
//  Why this is legitimate:
//    - The user explicitly started a transcription they want finished.
//    - The app already has the "audio" background mode for recording.
//    - We mix with other audio so we don't interrupt Spotify/YouTube.
//    - We stop as soon as the work is done (no persistent drain).
//

import Foundation
import AVFoundation
import UIKit

final class BackgroundKeepAlive {
    static let shared = BackgroundKeepAlive()

    private let engine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var refCount = 0
    private let lock = NSLock()

    private init() {}

    /// Reference-counted begin — safe to call from nested scopes. The
    /// keep-alive stays active until an equal number of `end()` calls.
    func begin() {
        lock.lock()
        defer { lock.unlock() }
        refCount += 1
        guard refCount == 1 else { return }
        startEngine()
    }

    func end() {
        lock.lock()
        defer { lock.unlock() }
        guard refCount > 0 else { return }
        refCount -= 1
        guard refCount == 0 else { return }
        stopEngine()
    }

    private func startEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Only touch the session if it's not already in a playback-
            // compatible state. RecordingService owns the session during
            // recording; we don't want to clobber it.
            if session.category != .playAndRecord && session.category != .playback {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try session.setActive(true, options: [])

            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
                AppLogger.warning("BackgroundKeepAlive: failed to build audio format", category: .transcription)
                return
            }

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)

            // 1-second silent buffer (already zeroed on creation).
            let frameCount = AVAudioFrameCount(format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                AppLogger.warning("BackgroundKeepAlive: failed to allocate silent buffer", category: .transcription)
                return
            }
            buffer.frameLength = frameCount

            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
            player.play()
            playerNode = player

            AppLogger.info("BackgroundKeepAlive: started silent audio loop for background execution", category: .transcription)
        } catch {
            AppLogger.warning("BackgroundKeepAlive: failed to start - \(error.localizedDescription)", category: .transcription)
            playerNode = nil
        }
    }

    private func stopEngine() {
        playerNode?.stop()
        if engine.isRunning {
            engine.stop()
        }
        playerNode = nil
        // Don't deactivate the session here — RecordingService may still
        // need it. iOS will clean it up when nothing's playing.
        AppLogger.info("BackgroundKeepAlive: stopped silent audio loop", category: .transcription)
    }
}
