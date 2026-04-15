//
//  DeepgramAudioCapture.swift
//  lecsy
//
//  マイク → 16kHz mono linear16 PCM Data チャンクへ変換してコールバック。
//  DeepgramStreamSession に直接流し込む。
//
//  参照: Deepgram/EXECUTION_PLAN.md W02
//
//  使い方:
//    let cap = DeepgramAudioCapture()
//    cap.onChunk = { data in session.send(audio: data) }
//    try cap.start()
//    // ...
//    cap.stop()
//

import Foundation
import AVFoundation

@MainActor
final class DeepgramAudioCapture {

    /// 変換済みチャンク（16kHz mono Int16 LE）が到着した時
    var onChunk: ((Data) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat = {
        // 16kHz mono Int16 interleaved little-endian（Deepgram linear16想定）
        var desc = AudioStreamBasicDescription(
            mSampleRate: 16_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        return AVAudioFormat(streamDescription: &desc)!
    }()

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredSampleRate(16_000)
        try session.setActive(true, options: [])

        let input = engine.inputNode
        let hwFormat = input.inputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            throw NSError(domain: "DeepgramAudioCapture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Converter init failed"])
        }
        self.converter = conv

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4_096, format: hwFormat) { [weak self] buffer, _ in
            self?.convertAndEmit(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func convertAndEmit(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
            return
        }

        var error: NSError?
        var provided = false
        let status = converter.convert(to: outBuf, error: &error) { _, outStatus in
            if provided {
                outStatus.pointee = .noDataNow
                return nil
            }
            provided = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil,
              let channelData = outBuf.int16ChannelData else { return }

        let frames = Int(outBuf.frameLength)
        let byteCount = frames * 2
        let ptr = UnsafeBufferPointer(start: channelData[0], count: frames)
        let data = Data(bytes: ptr.baseAddress!, count: byteCount)

        // UIスレッドではなく、コールバック内で同期的に送信（WebSocket I/Oは別Task）
        Task { @MainActor [weak self] in
            self?.onChunk?(data)
        }
    }
}
