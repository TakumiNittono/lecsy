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
        cfg.timeoutIntervalForRequest = 30
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

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp) = try await session.data(for: req)
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
        case 403: throw SupabaseError.forbidden
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
