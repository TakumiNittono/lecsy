//
//  LanguagePickerSheet.swift
//  lecsy
//

import SwiftUI

struct LanguagePickerSheet: View {
    let selectedLanguage: TranscriptionLanguage
    let onSelect: (TranscriptionLanguage) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Language")
                    .font(.headline)
                Text("Choose the language of your lecture")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            // Language grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                    Button {
                        onSelect(language)
                    } label: {
                        VStack(spacing: 4) {
                            Text(language.flag)
                                .font(.title2)
                            Text(language.shortName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedLanguage == language ? Color.blue : Color.secondary.opacity(0.08))
                        .foregroundStyle(selectedLanguage == language ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
