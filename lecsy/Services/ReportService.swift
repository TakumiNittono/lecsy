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
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bug: return "Bug"
        case .crash: return "Crash"
        case .feature: return "Feature Request"
        case .transcription: return "Transcription Issue"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .crash: return "exclamationmark.triangle"
        case .feature: return "lightbulb"
        case .transcription: return "text.bubble"
        case .other: return "ellipsis.circle"
        }
    }
}

@MainActor
class ReportService: ObservableObject {
    static let shared = ReportService()

    @Published var isSubmitting = false

    private init() {}

    /// Submit a problem report via email. Returns false if Mail is not available.
    func submitReport(
        category: ReportCategory,
        title: String,
        description: String,
        email: String?
    ) -> Bool {
        let device = UIDevice.current
        let deviceInfo = "\(device.model), iOS \(device.systemVersion)"
        let appVersion = Bundle.main.appVersion ?? "1.0.0"

        let subject = "[\(category.displayName)] \(title)"
        let body = """
        \(description)

        ---
        Category: \(category.displayName)
        Device: \(deviceInfo)
        App Version: \(appVersion)
        Contact: \(email ?? "Not provided")
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "mailto:support@lecsy.app?subject=\(encodedSubject)&body=\(encodedBody)"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        UIApplication.shared.open(url)
        return true
    }
}

extension Bundle {
    var appVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
