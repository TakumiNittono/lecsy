//
//  SupabaseClient.swift
//  lecsy
//
//  Lightweight HTTP client for Supabase REST + Edge Functions.
//  Used by the B2B organization features (v4).
//

import Foundation

enum SupabaseError: Error, LocalizedError {
    case missingConfig
    case unauthorized
    case forbidden
    case notFound
    case server(String, Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig:    return "Supabase configuration missing"
        case .unauthorized:     return "Not signed in"
        case .forbidden:        return "Insufficient permissions"
        case .notFound:         return "Not found"
        case .server(let m, let c): return "Server error \(c): \(m)"
        case .decoding(let m):  return "Decoding error: \(m)"
        }
    }
}

@MainActor
final class LecsyAPIClient {
    static let shared = LecsyAPIClient()

    /// Auth state is owned by `AuthService`. These are computed accessors so the
    /// HTTP client always reads the freshest token from the canonical source —
    /// no risk of PostLoginCoordinator and AuthService getting out of sync.
    var accessToken: String? {
        get { AuthService.shared.cachedAccessToken }
        set { /* no-op: AuthService is the source of truth */ }
    }
    var userId: String? {
        get { AuthService.shared.currentUser?.id.uuidString }
        set { /* no-op */ }
    }
    var userEmail: String? {
        get { AuthService.shared.currentUser?.email }
        set { /* no-op */ }
    }

    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession

    private init() {
        let info = Bundle.main.infoDictionary
        let urlString = (info?["SUPABASE_URL"] as? String) ?? ""
        let key = (info?["SUPABASE_ANON_KEY"] as? String) ?? ""
        self.baseURL = URL(string: urlString) ?? URL(string: "https://invalid")!
        self.anonKey = key
        let cfg = URLSessionConfiguration.default
        // VPN 経由 (WireGuard/OpenVPN/iCloud Private Relay 等) で QUIC が MTU 断片化で
        // 詰まる + NWPath が頻繁に unsatisfied/satisfied を行き来する環境に耐える設定:
        // - timeoutIntervalForRequest を 30 → 60 に延長 (VPN 経由の TLS handshake は
        //   倍の時間がかかる事がある)
        // - waitsForConnectivity=true で一時的な -1009 "offline" を即失敗にせず、
        //   NWPath が復帰するまで待つ。VPN 切替時の数秒 blackout を自動吸収
        // - networkServiceType=.responsiveData で iOS に「低遅延経路優先」を宣言、
        //   QUIC 優先度と競合時に HTTP/2 fallback が早く選ばれやすくなる
        cfg.timeoutIntervalForRequest = 60
        cfg.waitsForConnectivity = true
        cfg.networkServiceType = .responsiveData
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - REST

    func restGET<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/rest/v1\(path)"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        applyAuth(&req)
        return try await perform(req)
    }

    func restPOST<T: Decodable>(_ path: String, body: Encodable, prefer: String = "return=representation") async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent("/rest/v1\(path)"))
        req.httpMethod = "POST"
        req.setValue(prefer, forHTTPHeaderField: "Prefer")
        applyAuth(&req)
        req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        return try await perform(req)
    }

    // MARK: - Edge Functions

    func invokeFunction<T: Decodable>(_ name: String, body: Encodable, timeout: TimeInterval? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent("/functions/v1/\(name)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(&req)
        req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        if let timeout {
            req.timeoutInterval = timeout
        }
        return try await perform(req)
    }

    /// Stream the response body of an Edge Function as UTF-8 text chunks.
    /// Use for endpoints that return a plain-text stream (e.g. OpenAI-backed
    /// summarization where we want to display partial output as it arrives).
    func streamFunction(_ name: String, body: Encodable, timeout: TimeInterval = 300) -> AsyncThrowingStream<String, Error> {
        // Use a dedicated URLSession for streaming requests. The shared
        // `session` has a 30s timeoutIntervalForRequest which kills long
        // streaming responses prematurely.
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = timeout       // time to first byte
        cfg.timeoutIntervalForResource = timeout * 2  // overall cap
        cfg.waitsForConnectivity = false
        let streamSession = URLSession(configuration: cfg)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent("/functions/v1/\(name)")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.timeoutInterval = timeout
                    applyAuth(&req)
                    req.httpBody = try JSONEncoder().encode(AnyEncodable(body))

                    let (bytes, resp) = try await streamSession.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                        throw SupabaseError.server("stream_failed", status)
                    }

                    var buffer: [UInt8] = []
                    buffer.reserveCapacity(1024)
                    for try await byte in bytes {
                        buffer.append(byte)
                        // 体感遅延最小化: 旧しきい値 256 バイトは英語 60+ tokens 相当
                        // (1 token ≈ 4 bytes) で first paint まで 2-4秒かかっていた。
                        // 16 バイトまで下げて要約ボタン押下からほぼ即座に最初の文字が出る。
                        // 下げすぎると SwiftUI 更新が嵩むので 16 が実用バランス。
                        // UTF-8 の multibyte を跨いだ場合 String(bytes:encoding:) が nil を返す
                        // ので、その時は buffer を flush せず次の byte まで待つ。
                        if byte == 0x0A || buffer.count >= 16 {
                            if let chunk = String(bytes: buffer, encoding: .utf8) {
                                continuation.yield(chunk)
                                buffer.removeAll(keepingCapacity: true)
                            }
                        }
                    }
                    if !buffer.isEmpty, let tail = String(bytes: buffer, encoding: .utf8) {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - RPC

    func rpc<T: Decodable>(_ function: String, params: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent("/rest/v1/rpc/\(function)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: params)
        return try await perform(req)
    }

    // MARK: - Internal

    private func applyAuth(_ req: inout URLRequest) {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        let token = accessToken ?? anonKey
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    /// `URLSession.data(for:)` をラップして、VPN / QUIC / iOS 由来の一時的エラーで
    /// 最大 2 回まで自動リトライする。
    /// - -1005 NetworkConnectionLost: QUIC/HTTP3 のアイドル接続が OS に切られた直後
    ///   (Apple の推奨対処がリトライ)
    /// - -1009 NotConnectedToInternet: VPN 切替中の数秒 blackout。waitsForConnectivity
    ///   でもたまに即失敗になる経路があるので手動で拾う
    /// - -1001 TimedOut: VPN の MTU 断片化で TLS handshake が詰まったケース。本物の
    ///   永続 timeout と区別できないが、2 回試して両方失敗なら諦める
    /// - その他 URLError (e.g. -1003 cannotFindHost) はネット構成そのものの問題なので
    ///   リトライしても意味がない → throw
    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let first as URLError where Self.isTransientNetworkError(first) {
            AppLogger.warning(
                "URLSession \(first.code.rawValue) on \(req.url?.path ?? "?") — retrying (1/2)",
                category: .general
            )
            do {
                return try await session.data(for: req)
            } catch let second as URLError where Self.isTransientNetworkError(second) {
                AppLogger.warning(
                    "URLSession \(second.code.rawValue) on \(req.url?.path ?? "?") — retrying (2/2)",
                    category: .general
                )
                return try await session.data(for: req)
            }
        }
    }

    /// VPN / QUIC 由来の一時エラー判定。Supabase REST の send / FERPA PATCH で共用する想定。
    private static func isTransientNetworkError(_ error: URLError) -> Bool {
        switch error.code {
        case .networkConnectionLost,      // -1005
             .notConnectedToInternet,      // -1009
             .timedOut,                    // -1001
             .dnsLookupFailed:             // -1006
            return true
        default:
            return false
        }
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp) = try await send(req)
        guard let http = resp as? HTTPURLResponse else {
            throw SupabaseError.server("invalid_response", 0)
        }
        switch http.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            do {
                return try JSONDecoder.iso8601.decode(T.self, from: data)
            } catch {
                throw SupabaseError.decoding(String(describing: error))
            }
        case 401: throw SupabaseError.unauthorized
        case 403:
            // ボディに機械可読なエラーコード(plan_upgrade_required等)が
            // 入っている可能性があるので、server(..., 403) にして伝搬する
            let body = String(data: data, encoding: .utf8) ?? "forbidden"
            if body.contains("plan_upgrade_required") || body.contains("budget_exceeded") ||
               body.contains("daily_cap") || body.contains("monthly_cap") ||
               body.contains("feature_disabled") {
                throw SupabaseError.server(body, 403)
            }
            throw SupabaseError.forbidden
        case 404: throw SupabaseError.notFound
        default:
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.server(msg, http.statusCode)
        }
    }
}

struct EmptyResponse: Decodable {}

/// Type-eraser so we can encode any Encodable through generics.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
