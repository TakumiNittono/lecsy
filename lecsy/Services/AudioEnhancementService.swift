//
//  AudioEnhancementService.swift
//  lecsy
//
//  録音後の音声ファイルを文字起こしに通す前に 2 段で下処理する軽量 service。
//
//    1. peakDBFS(audioURL:)  — 先頭〜末尾を順にバッファで走査し、最大絶対値の
//       sample から dBFS を返す。1時間録音でも I/O バウンドで ~5-10秒。
//    2. enhance(audioURL:)   — peak をもう一度測って、フルスケール -1dBFS を目標に
//       ゲイン (上限 +15dB) をかけた m4a を Caches/ 以下に書き出して URL を返す。
//       既に十分ラウド (gain ≤ 1.0) な録音は元 URL に近い振幅のまま複製される。
//
//  呼び出し元（RecordView / LectureDetailView）は書き出された URL を文字起こしに
//  渡したあと `FileManager.removeItem(at:)` で片付ける前提。失敗は投げるだけで、
//  呼び出し元が raw audio で fallback する。
//

import Foundation
import AVFoundation

@MainActor
final class AudioEnhancementService {

    static let shared = AudioEnhancementService()

    private init() {}

    enum EnhancementError: Error {
        case openFailed(String)
        case readFailed(String)
        case writeFailed(String)
        case emptyAudio
    }

    /// 最大ゲイン (dB)。これを超えるブーストは SNR を悪化させるだけなので打ち止めにする。
    private let maxGainDB: Double = 15
    /// Target peak (dBFS). -1 に張り付けるとクリップの恐れがあるため -1dBFS を狙う。
    private let targetPeakDB: Double = -1

    // MARK: - Public API

    /// 音声全体の最大振幅を dBFS で返す。無音なら -infinity を返し、呼び出し側で
    /// `.isFinite` で弾く想定。
    func peakDBFS(audioURL: URL) async throws -> Double {
        try await Task.detached(priority: .utility) { [audioURL] in
            try Self.scanPeak(audioURL: audioURL)
        }.value
    }

    /// 振幅正規化した m4a を一時ディレクトリに書き出して URL を返す。呼び出し側が
    /// 使い終わったら `removeItem(at:)` すること。
    func enhance(audioURL: URL) async throws -> URL {
        try await Task.detached(priority: .utility) { [audioURL, maxGainDB, targetPeakDB] in
            try Self.renderEnhanced(
                audioURL: audioURL,
                maxGainDB: maxGainDB,
                targetPeakDB: targetPeakDB
            )
        }.value
    }

    /// 録音ファイル (.m4a) が moov atom 破損 / atom order 異常で AVAudioFile に
    /// 開けない場合の修復 path。AVAssetExportSession を使って同じ AAC を新しい
    /// .m4a コンテナに再 mux する。再生・読み出しは復活するが、samples 自体に
    /// 物理的損傷がある場合はそこは復旧できない (best-effort)。
    ///
    /// 呼び出し側は `audioLoadFailed` を catch した時に 1 度だけこの関数を試し、
    /// 成功したら返り URL で再 transcribe を仕掛ける。失敗時は元の error を
    /// そのまま投げる (呼び出し側はもう諦めるしかない)。
    /// memory `feedback_audio_must_survive.md` 「m4a 再生不能は障害扱い。
    /// AVAssetExportSession で自動 re-mux 修復までやる」を実装する物。
    func repair(audioURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: audioURL)
        // export presets が利用可能か事前チェック (壊れすぎてると false が返る)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        guard presets.contains(AVAssetExportPresetAppleM4A) else {
            throw EnhancementError.openFailed("File too damaged to repair (no compatible export preset)")
        }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw EnhancementError.openFailed("Could not create export session")
        }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("repaired-\(UUID().uuidString).m4a")
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = true  // moov atom を先頭に置き直す = 修復の核

        await exporter.export()

        switch exporter.status {
        case .completed:
            AppLogger.info("AudioEnhancement: re-muxed corrupt m4a successfully (\(audioURL.lastPathComponent))", category: .recording)
            return outURL
        case .failed, .cancelled:
            try? FileManager.default.removeItem(at: outURL)
            let detail = exporter.error?.localizedDescription ?? "unknown export error"
            throw EnhancementError.writeFailed("Repair export failed: \(detail)")
        default:
            try? FileManager.default.removeItem(at: outURL)
            throw EnhancementError.writeFailed("Repair export ended in unexpected state \(exporter.status.rawValue)")
        }
    }

    // MARK: - Implementation (nonisolated, runs on detached Task)

    private nonisolated static func scanPeak(audioURL: URL) throws -> Double {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: audioURL)
        } catch {
            throw EnhancementError.openFailed(error.localizedDescription)
        }

        let format = file.processingFormat
        let frameCapacity: AVAudioFrameCount = 16_384
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw EnhancementError.readFailed("Could not allocate read buffer")
        }

        var peak: Float = 0
        while file.framePosition < file.length {
            do {
                try file.read(into: buffer)
            } catch {
                throw EnhancementError.readFailed(error.localizedDescription)
            }
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }

            if let floatData = buffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    let ptr = floatData[ch]
                    for i in 0..<frames {
                        let v = abs(ptr[i])
                        if v > peak { peak = v }
                    }
                }
            } else if let int16Data = buffer.int16ChannelData {
                let scale: Float = 1.0 / Float(Int16.max)
                for ch in 0..<Int(format.channelCount) {
                    let ptr = int16Data[ch]
                    for i in 0..<frames {
                        let v = abs(Float(ptr[i])) * scale
                        if v > peak { peak = v }
                    }
                }
            }
        }

        guard peak > 0 else { return -.infinity }
        return 20.0 * log10(Double(peak))
    }

    private nonisolated static func renderEnhanced(
        audioURL: URL,
        maxGainDB: Double,
        targetPeakDB: Double
    ) throws -> URL {
        let inFile: AVAudioFile
        do {
            inFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw EnhancementError.openFailed(error.localizedDescription)
        }

        let peakDB = try scanPeak(audioURL: audioURL)
        let gainLinear: Float
        if peakDB.isFinite {
            let desiredGainDB = min(targetPeakDB - peakDB, maxGainDB)
            gainLinear = desiredGainDB > 0 ? Float(pow(10.0, desiredGainDB / 20.0)) : 1.0
        } else {
            gainLinear = 1.0
        }

        let processingFormat = inFile.processingFormat

        // 出力は m4a (AAC)。録音ファイルと揃えると Deepgram Batch / WhisperKit 双方の
        // demux パスを通るので扱いが揃う。
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("enhanced-\(UUID().uuidString).m4a")

        let outSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: processingFormat.sampleRate,
            AVNumberOfChannelsKey: processingFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let outFile: AVAudioFile
        do {
            outFile = try AVAudioFile(forWriting: outURL, settings: outSettings)
        } catch {
            throw EnhancementError.writeFailed(error.localizedDescription)
        }

        let frameCapacity: AVAudioFrameCount = 16_384
        guard let readBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCapacity) else {
            throw EnhancementError.readFailed("Could not allocate read buffer")
        }

        inFile.framePosition = 0
        while inFile.framePosition < inFile.length {
            do {
                try inFile.read(into: readBuffer)
            } catch {
                throw EnhancementError.readFailed(error.localizedDescription)
            }
            let frames = Int(readBuffer.frameLength)
            if frames == 0 { break }

            if gainLinear != 1.0, let floatData = readBuffer.floatChannelData {
                for ch in 0..<Int(processingFormat.channelCount) {
                    let ptr = floatData[ch]
                    for i in 0..<frames {
                        var s = ptr[i] * gainLinear
                        // Hard-limit to avoid clipping even with maxGain cap.
                        if s > 1.0 { s = 1.0 } else if s < -1.0 { s = -1.0 }
                        ptr[i] = s
                    }
                }
            } else if gainLinear != 1.0, let int16Data = readBuffer.int16ChannelData {
                let maxVal: Float = Float(Int16.max)
                let minVal: Float = Float(Int16.min)
                for ch in 0..<Int(processingFormat.channelCount) {
                    let ptr = int16Data[ch]
                    for i in 0..<frames {
                        var s = Float(ptr[i]) * gainLinear
                        if s > maxVal { s = maxVal } else if s < minVal { s = minVal }
                        ptr[i] = Int16(s)
                    }
                }
            }

            do {
                try outFile.write(from: readBuffer)
            } catch {
                throw EnhancementError.writeFailed(error.localizedDescription)
            }
        }

        return outURL
    }
}
