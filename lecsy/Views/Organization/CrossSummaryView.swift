//
//  CrossSummaryView.swift
//  lecsy
//
//  組織メンバー限定: 講義のクロス言語要約表示
//

import SwiftUI

struct CrossSummaryView: View {
    let transcriptId: UUID
    @StateObject private var orgService = OrganizationService.shared
    @State private var selectedLanguage = "ja"
    @State private var result: CrossSummaryResult?
    @State private var isLoading = false
    @State private var error: String?

    private let languages: [(code: String, name: String)] = [
        ("ja", "Japanese"), ("en", "English"), ("es", "Spanish"),
        ("zh", "Chinese"), ("ko", "Korean"), ("fr", "French"),
        ("de", "German"), ("pt", "Portuguese"), ("it", "Italian"),
        ("ru", "Russian"), ("ar", "Arabic"), ("hi", "Hindi"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.indigo)
                Text("Cross-Language Summary")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                orgBadge
            }

            // Language picker
            HStack {
                Text("Translate to:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)
            }

            // Generate button
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Generating..." : "Generate Summary")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.indigo)
                .foregroundColor(.white)
                .font(.subheadline.weight(.semibold))
                .cornerRadius(10)
            }
            .disabled(isLoading)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Result
            if let result {
                resultView(result)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .onAppear {
            // キャッシュがあれば表示
            if let cached = orgService.getCachedCrossSummary(transcriptId: transcriptId, targetLanguage: selectedLanguage) {
                result = cached
            }
        }
    }

    private var orgBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.2")
            Text("B2B")
        }
        .font(.caption2.weight(.semibold))
        .foregroundColor(.indigo)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.indigo.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func resultView(_ result: CrossSummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Language badge
            HStack(spacing: 4) {
                Text(result.sourceLanguage)
                    .font(.caption2)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(result.targetLanguage)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundColor(.indigo)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.indigo.opacity(0.08))
            .cornerRadius(6)

            // Summary
            Text(result.summary)
                .font(.subheadline)
                .foregroundColor(.primary)

            // Key Points
            if !result.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Points")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(result.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(Color.indigo)
                                .frame(width: 5, height: 5)
                                .offset(y: 5)
                            Text(point)
                                .font(.caption)
                        }
                    }
                }
            }

            // Sections
            if !result.sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sections")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.heading)
                                .font(.caption.weight(.medium))
                            Text(section.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.indigo.opacity(0.3))
                                .frame(width: 2)
                        }
                    }
                }
            }

            // Bilingual Terms
            if let terms = result.keyTermsBilingual, !terms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Terms")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(terms) { term in
                        HStack(spacing: 6) {
                            Text(term.original)
                                .font(.caption.weight(.medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text(term.translated)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.indigo)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func generate() async {
        isLoading = true
        error = nil

        do {
            let summaryResult = try await orgService.fetchCrossSummary(
                transcriptId: transcriptId,
                targetLanguage: selectedLanguage
            )
            result = summaryResult
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
