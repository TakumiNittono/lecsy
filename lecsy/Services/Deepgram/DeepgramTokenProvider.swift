//
//  DeepgramTokenProvider.swift
//  lecsy
//
//  Edge Function `deepgram-token` から短寿命トークンを取得。
//  参照: Deepgram/EXECUTION_PLAN.md W01-W02
//
//  使い方:
//    let provider = DeepgramTokenProvider()
//    let token = try await provider.issueToken()
//

import Foundation

protocol DeepgramTokenProviderProtocol: Sendable {
    func issueToken() async throws -> String
}

/// MainActor分離を避けつつ、実際の発行時だけ MainActor上で client を掴む遅延 provider
final class _LazyTokenProvider: DeepgramTokenProviderProtocol {
    func issueToken() async throws -> String {
        try await MainActor.run {
            DeepgramTokenProvider()
        }.issueToken()
    }
}

enum DeepgramTokenError: Error, LocalizedError {
    case unauthorized
    case budgetExceeded       // L1: Deepgram残高不足
    case dailyCap             // L3: 日次上限120分
    case monthlyCap           // L2: 月次上限600分
    case featureDisabled      // Feature flag OFF
    case serverMisconfigured
    case decodeFailure
    case network(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:        return "ログインが必要です"
        case .budgetExceeded:      return "サービス一時停止中（予算保護）"
        case .dailyCap:            return "本日のリアルタイム字幕は上限に達しました（120分/日）"
        case .monthlyCap:          return "今月のリアルタイム字幕は上限に達しました"
        case .featureDisabled:     return "リアルタイム字幕は現在利用できません"
        case .serverMisconfigured: return "サーバ設定エラー"
        case .decodeFailure:       return "レスポンス解析失敗"
        case .network(let code):   return "ネットワークエラー (\(code))"
        }
    }
}

struct DeepgramTokenResponse: Decodable {
    let token: String
    let ttl_seconds: Int
}

private struct EmptyBody: Encodable {}

/// `LecsyAPIClient` 経由で Supabase Edge Function を叩く実装
@MainActor
final class DeepgramTokenProvider: DeepgramTokenProviderProtocol {

    private let client: LecsyAPIClient

    /// デフォルト client（`LecsyAPIClient.shared`）で初期化。
    /// Swift 6 strict concurrency で default 引数に `@MainActor` 参照を置くと
    /// "referenced from nonisolated context" 警告になるため、body 内で解決する。
    init() {
        self.client = LecsyAPIClient.shared
    }

    init(client: LecsyAPIClient) {
        self.client = client
    }

    /// nonisolatedコンテキスト(例: `static let shared` の初期化)から生成する。
    /// `LecsyAPIClient.shared` は `@MainActor` シングルトンだが、
    /// ここでは clientへの参照を遅延させるため軽量wrapperを返す。
    nonisolated static func nonisolatedMakeDefault() -> DeepgramTokenProviderProtocol {
        _LazyTokenProvider()
    }

    func issueToken() async throws -> String {
        do {
            let res: DeepgramTokenResponse = try await client.invokeFunction(
                "deepgram-token",
                body: EmptyBody(),
                timeout: 15
            )
            return res.token
        } catch SupabaseError.unauthorized {
            throw DeepgramTokenError.unauthorized
        } catch let SupabaseError.server(msg, code) {
            // Edge Function の error フィールドから分岐
            if msg.contains("budget_exceeded")     { throw DeepgramTokenError.budgetExceeded }
            if msg.contains("daily_cap")           { throw DeepgramTokenError.dailyCap }
            if msg.contains("monthly_cap")         { throw DeepgramTokenError.monthlyCap }
            if msg.contains("feature_disabled")    { throw DeepgramTokenError.featureDisabled }
            if msg.contains("server_misconfigured"){ throw DeepgramTokenError.serverMisconfigured }
            throw DeepgramTokenError.network(code)
        } catch SupabaseError.decoding {
            throw DeepgramTokenError.decodeFailure
        } catch {
            throw DeepgramTokenError.network(-1)
        }
    }
}
