//
//  TranslationStream.swift
//  lecsy
//
//  Deepgramの確定セグメント毎に translate-realtime Edge Function を呼び出し、
//  結果を @Published で UI に配信する。
//
//  参照: Deepgram/EXECUTION_PLAN.md W03
//

import Foundation
import Combine

/// 翻訳先言語の選択肢。母語＝留学生が読みたい言語。
enum TranslationTargetLanguage: String, CaseIterable, Identifiable {
    case japanese    = "ja"
    case english     = "en"
    case chinese     = "zh"
    case korean      = "ko"
    case vietnamese  = "vi"
    case spanish     = "es"
    case portuguese  = "pt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese:   return "日本語"
        case .english:    return "English"
        case .chinese:    return "中文"
        case .korean:     return "한국어"
        case .vietnamese: return "Tiếng Việt"
        case .spanish:    return "Español"
        case .portuguese: return "Português"
        }
    }

    static let userDefaultsKey = "lecsy.translationTargetLang"

    static var current: TranslationTargetLanguage {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        return TranslationTargetLanguage(rawValue: raw) ?? .japanese
    }

    static func set(_ lang: TranslationTargetLanguage) {
        UserDefaults.standard.set(lang.rawValue, forKey: userDefaultsKey)
        NotificationCenter.default.post(name: .translationTargetDidChange, object: lang)
    }
}

extension Notification.Name {
    static let translationTargetDidChange = Notification.Name("lecsy.translationTargetDidChange")
}

@MainActor
final class TranslationStream: ObservableObject {

    struct TranslatedSegment: Identifiable, Equatable {
        let id: UUID           // DeepgramStreamSession.Segment.id と同一
        let sourceText: String
        var translatedText: String
        let targetLang: String
        let sourceStart: Double
        let sourceEnd: Double
        var status: Status

        enum Status: Equatable { case pending, done, failed(String) }
    }

    @Published private(set) var translatedSegments: [TranslatedSegment] = []

    /// サーバから "plan_upgrade_required" を受けたら true。
    /// UI側で翻訳カラムをアップセルCTAに差し替える。
    @Published private(set) var upgradeRequired: Bool = false

    /// 翻訳先言語。UserDefaultsから常にfresh読み取り（Settingsで変えたら次のセグメントから即反映）
    var targetLang: String { TranslationTargetLanguage.current.rawValue }

    private let client: LecsyAPIClient
    private var inflight: Set<UUID> = []

    init() {
        self.client = LecsyAPIClient.shared
    }

    init(client: LecsyAPIClient) {
        self.client = client
    }

    /// 新しい確定セグメントが来たら呼ぶ。重複は内部で排除。
    /// アップグレード必要状態の時はスキップ（サーバに打たない）。
    func enqueue(_ segment: DeepgramStreamSession.Segment) {
        guard !upgradeRequired else { return }
        guard !inflight.contains(segment.id),
              !translatedSegments.contains(where: { $0.id == segment.id }) else {
            return
        }
        inflight.insert(segment.id)

        let pending = TranslatedSegment(
            id: segment.id,
            sourceText: segment.text,
            translatedText: "",
            targetLang: targetLang,
            sourceStart: segment.start,
            sourceEnd: segment.end,
            status: .pending
        )
        translatedSegments.append(pending)

        Task { [weak self, segment, targetLang = self.targetLang] in
            guard let self else { return }
            await self.performTranslation(segment: segment, targetLang: targetLang)
        }
    }

    /// 字幕セッション切替時にクリア
    func reset() {
        translatedSegments = []
        inflight.removeAll()
        upgradeRequired = false
    }

    // MARK: - Private

    private struct Request: Encodable {
        let text: String
        let target_lang: String
        let source_lang: String?
    }

    private struct Response: Decodable {
        let translated: String
        let target_lang: String
    }

    private func performTranslation(
        segment: DeepgramStreamSession.Segment,
        targetLang: String
    ) async {
        defer { inflight.remove(segment.id) }

        do {
            let res: Response = try await client.invokeFunction(
                "translate-realtime",
                body: Request(
                    text: segment.text,
                    target_lang: targetLang,
                    source_lang: segment.language
                ),
                timeout: 20
            )
            if let idx = translatedSegments.firstIndex(where: { $0.id == segment.id }) {
                translatedSegments[idx].translatedText = res.translated
                translatedSegments[idx].status = .done
            }
        } catch {
            AppLogger.warning("Translation failed: \(error.localizedDescription)", category: .transcription)

            // plan_upgrade_required を検出したら以降を全部止める
            let shouldLock: Bool = {
                if case let SupabaseError.server(body, code) = error, code == 403 {
                    return body.contains("plan_upgrade_required")
                }
                if case SupabaseError.forbidden = error {
                    // translate-realtimeの403は翻訳プランgateのみ原因なのでupgradeを引く
                    return true
                }
                let msg = error.localizedDescription.lowercased()
                return msg.contains("plan_upgrade_required") || msg.contains("plan upgrade")
            }()

            if shouldLock {
                upgradeRequired = true
            }

            if let idx = translatedSegments.firstIndex(where: { $0.id == segment.id }) {
                translatedSegments[idx].status = .failed(error.localizedDescription)
            }
        }
    }
}
