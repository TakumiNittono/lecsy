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
    private var didLogFirstChunk = false
    private var chunkWatchdog: Task<Void, Never>?
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
        // AVAudioSession は RecordingService が所有する。ここでは触らない。
        //
        // engine.start() を先に呼ぶ: input node の format は engine が走るまで
        // 確定しない（0 channels / 0 Hz を返すことがある）ので、start 後に
        // 実際の hw format を取得してからタップを張る方が確実。
        let input = engine.inputNode

        engine.prepare()
        try engine.start()

        let hwFormat = input.outputFormat(forBus: 0)
        AppLogger.info("Deepgram: audio engine started — hwFormat=\(hwFormat.sampleRate)Hz ch=\(hwFormat.channelCount) fmt=\(hwFormat.commonFormat.rawValue)", category: .transcription)

        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            engine.stop()
            throw NSError(domain: "DeepgramAudioCapture", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Input node returned invalid format after engine.start"])
        }

        guard let conv = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            engine.stop()
            throw NSError(domain: "DeepgramAudioCapture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Converter init failed"])
        }
        self.converter = conv

        input.removeTap(onBus: 0)
        // format: nil で node の native 形式を自動採用。hwFormat を渡すと
        // 実 format と食い違った時に tap が発火しないことがある。
        input.installTap(onBus: 0, bufferSize: 4_096, format: nil) { [weak self] buffer, _ in
            self?.convertAndEmit(buffer: buffer)
        }

        // 3秒経っても chunk が届かなければ警告。
        // tap の silent failure（AVAudioRecorder と hardware input を取り合って
        // buffer が来ないケース）を検知するため。
        didLogFirstChunk = false
        chunkWatchdog?.cancel()
        chunkWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                if !self.didLogFirstChunk {
                    AppLogger.warning("Deepgram: no audio chunk after 3s — tap may be silent (AVAudioRecorder conflict?)", category: .transcription)
                }
            }
        }
    }

    func stop() {
        chunkWatchdog?.cancel()
        chunkWatchdog = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // AVAudioSession.setActive(false) は呼ばない。
        // RecordingService がまだセッションを使っている可能性があるため。
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
            guard let self else { return }
            if !self.didLogFirstChunk {
                self.didLogFirstChunk = true
                AppLogger.info("Deepgram: first audio chunk emitted (\(byteCount) bytes, \(frames) frames @16kHz)", category: .transcription)
            }
            self.onChunk?(data)
        }
    }
}
