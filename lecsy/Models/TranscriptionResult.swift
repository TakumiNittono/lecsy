//
//  TranscriptionResult.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// Transcription result
struct TranscriptionResult: Codable, Equatable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
    let processingTime: TimeInterval

    struct TranscriptionSegment: Codable, Identifiable, Equatable {
        var id: String { "\(startTime)-\(endTime)" }
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String

        /// Cleaned text with Whisper tokens removed
        var cleanText: String {
            Self.stripWhisperTokens(text)
        }

        private enum CodingKeys: String, CodingKey {
            case startTime, endTime, text
        }

        /// Remove Whisper special tokens + normalize failure markers + collapse
        /// hallucination-style repeated runs.
        ///
        /// 2026-04-26 (お父様フィードバック): 認識失敗時の出力が
        ///   1) 何も出ない (drop) — ここでは扱わない (segment 自体が無いため別経路で対応)
        ///   2) `[Silence]` / `[inaudible]` が混在
        ///   3) 同じ語句が 4回以上連続
        /// と 3 パターンに分かれて見え方がバラバラだった。
        /// 2/3 をすべて単一の `[inaudible]` に正規化することで、ユーザーから見て
        /// 「失敗したことが一目で分かる」体験に揃える。
        static func stripWhisperTokens(_ input: String) -> String {
            // 1) Whisper の <|...|> 特殊トークンを除去
            //    例: <|startoftranscript|>, <|en|>, <|0.00|>
            var cleaned = input.replacingOccurrences(
                of: "<\\|[^|]*\\|>",
                with: "",
                options: .regularExpression
            )

            // 2) 失敗マーカーを `[inaudible]` に統一。
            //    Whisper/Deepgram で時々出る `[Silence]`, `[silent]`, `[BLANK_AUDIO]`,
            //    `[NO_SPEECH]` 等を全部まとめる。
            //    `[inaudible]` 自体はそのまま残す (重複置換しても結果は同じ)。
            cleaned = cleaned.replacingOccurrences(
                of: "\\[(?:silence|silent|blank[_\\s]?audio|no[_\\s]?speech|music|noise)\\]",
                with: "[inaudible]",
                options: [.regularExpression, .caseInsensitive]
            )

            // 3) Hallucination 抑制: 同一の単語/短句が 4回以上連続したら `[inaudible]` に縮約。
            //    例: "thank you thank you thank you thank you thank you" → "[inaudible]"
            //    Whisper が低 SNR 区間でループに入る挙動への対処。
            //    最大 25 文字までの繰り返し単位を対象 (それ以上長い節は誤検知リスク高)。
            cleaned = collapseRepeatedRuns(cleaned)

            // 4) 連続する `[inaudible]` をひとつに圧縮
            cleaned = cleaned.replacingOccurrences(
                of: "(?:\\[inaudible\\]\\s*){2,}",
                with: "[inaudible] ",
                options: .regularExpression
            )

            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// 同じトークン (単語 or 短句) が 4 回以上連続している箇所を `[inaudible]` に置換。
        /// 大文字小文字・末尾の句読点/空白の差異は無視して同一視する。
        ///
        /// パフォーマンス: 1 時間講演 (~10K segments) の transcript ~50KB 規模を想定し、
        /// 単一パスで処理。正規表現の back-reference は Foundation の NSRegularExpression
        /// で機能するので利用する。
        private static func collapseRepeatedRuns(_ input: String) -> String {
            // パターン: (単語境界)(1〜25 文字の単位)(空白) → 同じ単位 + 空白 が 3 回以上 (合計 4 回以上連続)
            // \\b\\S{1,25}\\b で「短い単位」を捉える。長い文を間違って巻き込まないため上限を切る。
            let pattern = "(\\b[\\p{L}\\p{N}'’]{1,25}\\b[\\p{P}\\s]+)(?:\\1){3,}"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return input
            }
            let nsInput = input as NSString
            let range = NSRange(location: 0, length: nsInput.length)
            return regex.stringByReplacingMatches(
                in: input,
                options: [],
                range: range,
                withTemplate: "[inaudible] "
            )
        }
    }

    /// Cleaned full text with Whisper tokens removed
    var cleanText: String {
        TranscriptionSegment.stripWhisperTokens(text)
    }
}
