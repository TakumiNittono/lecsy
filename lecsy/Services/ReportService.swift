//
//  ReportService.swift
//  lecsy
//

import Foundation
import UIKit
import Combine

enum ReportCategory: String, CaseIterable, Identifiable {
    case bug = "bug"
    case crash = "crash"
    case feature = "feature"
    case transcription = "transcription"
    case sync = "sync"
    case account = "account"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bug: return "Bug"
        case .crash: return "Crash"
        case .feature: return "Feature Request"
        case .transcription: return "Transcription Issue"
        case .sync: return "Sync Issue"
        case .account: return "Account Issue"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .crash: return "exclamationmark.triangle"
        case .feature: return "lightbulb"
        case .transcription: return "text.bubble"
        case .sync: return "arrow.triangle.2.circlepath"
        case .account: return "person.crop.circle"
        case .other: return "ellipsis.circle"
        }
    }
}

@MainActor
class ReportService: ObservableObject {
    static let shared = ReportService()

    @Published var isSubmitting = false

    private let authService = AuthService.shared

    private init() {}

    /// Submit a problem report
    func submitReport(
        category: ReportCategory,
        title: String,
        description: String,
        email: String?
    ) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        let config = SupabaseConfig.shared
        let functionURL = config.supabaseURL.appendingPathComponent("functions/v1/submit-report")

        var urlRequest = URLRequest(url: functionURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        // Attach auth if available
        if let accessToken = await authService.accessToken {
            let authHeader = accessToken.hasPrefix("Bearer ") ? accessToken : "Bearer \(accessToken)"
            urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        let device = UIDevice.current
        let deviceInfo = "\(device.model), iOS \(device.systemVersion)"
        let appVersion = Bundle.main.appVersion ?? "1.0.0"

        let requestBody: [String: Any?] = [
            "category": category.rawValue,
            "title": title,
            "description": description,
            "email": email,
            "device_info": deviceInfo,
            "app_version": appVersion,
            "platform": "ios"
        ]

        // Filter out nil values
        let filteredBody = requestBody.compactMapValues { $0 }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: filteredBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportError.submitFailed("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorMessage = "Unknown error"
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let message = errorData["error"] {
                errorMessage = message
            }
            AppLogger.error("ReportService: Submit failed - Status: \(httpResponse.statusCode), Message: \(errorMessage)", category: .general)
            throw ReportError.submitFailed(errorMessage)
        }

        AppLogger.info("ReportService: Report submitted successfully", category: .general)
    }
}

enum ReportError: LocalizedError {
    case submitFailed(String)

    var errorDescription: String? {
        switch self {
        case .submitFailed(let message):
            return "Failed to submit report: \(message)"
        }
    }
}
