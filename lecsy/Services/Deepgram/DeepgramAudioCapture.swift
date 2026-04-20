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
// AVFoundation の型（AVAudioPCMBuffer 等）は Sendable 未対応なので、
// Swift 6 strict concurrency で警告が出ないよう preconcurrency import する。
@preconcurrency import AVFoundation

@MainActor
final class DeepgramAudioCapture {

    /// 変換済みチャンク（16kHz mono Int16 LE）が到着した時
    var onChunk: ((Data) -> Void)?

    /// 10秒以上 chunk が届かず tap が dead と判断された時に呼ぶ。
    /// 呼び出し元は画面にエラーを出して停止する責務を持つ。
    var onSilenceFailure: (() -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var didLogFirstChunk = false
    private var chunkWatchdog: Task<Void, Never>?
    /// start() 後かどうか。interruption handler が start 前/stop 後に誤動作しないようガード。
    private var isRunning = false
    /// Interruption 中は再起動を試みない。`.ended` で true に戻す。
    private var isInterrupted = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?

    // NotificationCenter observers は stop() で明示的に解除する。
    // deinit は @MainActor class では Swift 6 で isolation 制約があるため cleanup を入れない。
    // observer ブロックは `[weak self]` で self を持たないので、stop 忘れ時も
    // self 解放後に空発火するだけで副作用はない（次の startLive で clean な状態になる）。

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
        try startEngineAndTap()
        isRunning = true
        registerAudioSessionObservers()
    }

    /// Engine を立ち上げてタップを張る。interruption .ended や media services reset
    /// 復帰時にも同じ手順で呼び直せるように分離。
    private func startEngineAndTap() throws {
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

        // 3秒経っても chunk が届かなければ警告。10秒で fatal 扱いにして
        // 停止させる（警告だけだと無音のまま Deepgram にゴミを流し続ける）。
        didLogFirstChunk = false
        chunkWatchdog?.cancel()
        chunkWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            // Swift 6 では同一スコープで `guard let self` を2回書くと2回目が
            // non-Optional 扱いになりエラー。`strongSelf` 名で1回だけ束縛する。
            guard !Task.isCancelled, let strongSelf = self else { return }
            let stillSilentAt3s: Bool = await MainActor.run {
                let silent = !strongSelf.didLogFirstChunk
                if silent {
                    AppLogger.warning("Deepgram: no audio chunk after 3s — tap may be silent (AVAudioRecorder conflict?)", category: .transcription)
                }
                return silent
            }
            guard stillSilentAt3s else { return }

            try? await Task.sleep(nanoseconds: 7_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                guard !strongSelf.didLogFirstChunk else { return }
                AppLogger.error("Deepgram: no audio chunk after 10s — aborting live transcription", category: .transcription)
                strongSelf.onSilenceFailure?()
            }
        }
    }

    func stop() {
        isRunning = false
        isInterrupted = false
        chunkWatchdog?.cancel()
        chunkWatchdog = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        unregisterAudioSessionObservers()
        // AVAudioSession.setActive(false) は呼ばない。
        // RecordingService がまだセッションを使っている可能性があるため。
    }

    // MARK: - Interruption handling
    //
    // 電話着信 / Siri / 他アプリの音声横取り / ヘッドホン抜去 / iOS のメディアサブシステム
    // リセット時、AVAudioEngine は system 側で停止される。RecordingService は自分で
    // `AVAudioSession.interruptionNotification` を観察して録音を再開するが、
    // このエンジンは独立して走っているため自前で再起動する必要がある。対応しないと
    // 電話から戻ってきた後の live captions が沈黙し続ける（watchdog は初回10秒のみ）。

    private func registerAudioSessionObservers() {
        let nc = NotificationCenter.default

        // `queue: .main` 指定で main thread 配送される。iOS 17+ なので
        // `MainActor.assumeIsolated` で Task wrap を避け、Swift 6 の
        // Sendable / captured var 警告群を根治する。
        interruptionObserver = nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawType = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? UInt.max
            MainActor.assumeIsolated {
                self?.handleInterruption(rawType: rawType)
            }
        }

        // ヘッドホン抜去等で input が変わる。hw format が変わったら converter も
        // 組み直す必要があるので、タップ再インストール込みで startEngineAndTap を呼ぶ。
        routeChangeObserver = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleRouteChange()
            }
        }

        // まれに iOS が audio stack 全体を再構築する。engine 内部ポインタが無効化される
        // ので完全再起動。
        mediaResetObserver = nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMediaServicesReset()
            }
        }
    }

    private func unregisterAudioSessionObservers() {
        let nc = NotificationCenter.default
        if let interruptionObserver {
            nc.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let routeChangeObserver {
            nc.removeObserver(routeChangeObserver)
            self.routeChangeObserver = nil
        }
        if let mediaResetObserver {
            nc.removeObserver(mediaResetObserver)
            self.mediaResetObserver = nil
        }
    }

    private func handleInterruption(rawType: UInt) {
        guard isRunning,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            isInterrupted = true
            AppLogger.debug("Deepgram: audio interruption began (phone/Siri) — engine paused by system", category: .transcription)
            // engine は system 側で止まる。明示的な stop は不要（route 再アクティベートの邪魔になる）
        case .ended:
            isInterrupted = false
            AppLogger.debug("Deepgram: audio interruption ended — restarting engine", category: .transcription)
            // RecordingService が session を再アクティベートしてから engine 再起動
            restartEngineAfterInterruption()
        @unknown default:
            break
        }
    }

    private func handleRouteChange() {
        // 録音中で、かつ interruption 中ではない状態で engine が止まっていたら再起動。
        // 通常 AVAudioEngine は route change を自動追従するが、
        // ヘッドホン抜去時に session が一時 deactivate されると engine も止まることがある。
        guard isRunning, !isInterrupted else { return }
        if !engine.isRunning {
            AppLogger.warning("Deepgram: engine stopped after route change — restarting", category: .transcription)
            restartEngineAfterInterruption()
        }
    }

    private func handleMediaServicesReset() {
        guard isRunning else { return }
        AppLogger.error("Deepgram: mediaServicesWereReset — full engine rebuild", category: .transcription)
        // 内部状態を全部捨てて再構築
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        restartEngineAfterInterruption()
    }

    /// Engine を再起動して tap を張り直す。失敗したら onSilenceFailure で上位に通知。
    /// 短いリトライ（300ms 後）を 1 回だけ入れる：session reactivation レースで
    /// 最初の start() が AVAudioError.cannotStartEngine になることがある。
    private func restartEngineAfterInterruption() {
        guard isRunning, !isInterrupted else { return }

        do {
            try startEngineAndTap()
            AppLogger.info("Deepgram: engine restarted after interruption", category: .transcription)
        } catch {
            AppLogger.warning("Deepgram: engine restart failed (\(error.localizedDescription)) — retrying in 300ms", category: .transcription)
            // Task.sleep を避けて DispatchQueue で遅延実行（Swift 6 の @Sendable 制約を回避）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.isRunning, !self.isInterrupted else { return }
                do {
                    try self.startEngineAndTap()
                    AppLogger.info("Deepgram: engine restarted on retry", category: .transcription)
                } catch {
                    AppLogger.error("Deepgram: engine restart failed after retry (\(error.localizedDescription)) — notifying caller", category: .transcription)
                    self.onSilenceFailure?()
                }
            }
        }
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

        // tap コールバックは非 MainActor スレッドから来る。Data は Sendable なので
        // DispatchQueue.main.async でホップ（Task wrap 版だと Swift 6 の var 'self' 警告を踏む）。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.didLogFirstChunk {
                self.didLogFirstChunk = true
                AppLogger.info("Deepgram: first audio chunk emitted (\(byteCount) bytes, \(frames) frames @16kHz)", category: .transcription)
            }
            self.onChunk?(data)
        }
    }
}
