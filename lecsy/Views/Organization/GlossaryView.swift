//
//  GlossaryView.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import SwiftUI

struct GlossaryView: View {
    @StateObject private var orgService = OrganizationService.shared
    @State private var searchText = ""
    @State private var filterDifficulty: GlossaryEntry.DifficultyLevel?
    @State private var filterLanguage: TranscriptionLanguage?
    @State private var showAddEntry = false

    private var filteredEntries: [GlossaryEntry] {
        var result = orgService.glossaryEntries
        if let diff = filterDifficulty {
            result = result.filter { $0.difficulty == diff }
        }
        if let lang = filterLanguage {
            result = result.filter { $0.targetLanguage == lang }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.term.lowercased().contains(query) ||
                $0.definition.lowercased().contains(query) ||
                $0.translation.lowercased().contains(query)
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            // Filters
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Difficulty filters
                        ForEach(GlossaryEntry.DifficultyLevel.allCases, id: \.self) { level in
                            filterChip(
                                title: level.displayName,
                                isSelected: filterDifficulty == level,
                                color: difficultyColor(level)
                            ) {
                                filterDifficulty = filterDifficulty == level ? nil : level
                            }
                        }

                        Divider().frame(height: 20)

                        // Language filters
                        let usedLanguages = Set(orgService.glossaryEntries.map { $0.targetLanguage })
                        ForEach(Array(usedLanguages).sorted(by: { $0.displayName < $1.displayName }), id: \.self) { lang in
                            filterChip(
                                title: "\(lang.flag) \(lang.shortName)",
                                isSelected: filterLanguage == lang,
                                color: .blue
                            ) {
                                filterLanguage = filterLanguage == lang ? nil : lang
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Entries
            if filteredEntries.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No glossary entries")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        glossaryRow(entry)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            orgService.removeGlossaryEntry(filteredEntries[index])
                        }
                    }
                } header: {
                    Text("\(filteredEntries.count) terms")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search terms")
        .navigationTitle("Glossary")
        .toolbar {
            if orgService.currentRole?.canGenerateGlossary == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            addEntrySheet
        }
    }

    // MARK: - Glossary Row

    private func glossaryRow(_ entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.term)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    Text(entry.difficulty.displayName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(difficultyColor(entry.difficulty))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(difficultyColor(entry.difficulty).opacity(0.12))
                        .clipShape(Capsule())

                    Text(entry.targetLanguage.flag)
                        .font(.caption)
                }
            }

            Text(entry.definition)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)

            if !entry.translation.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text(entry.translation)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.blue)
                }
            }

            if !entry.example.isEmpty {
                Text("\"\(entry.example)\"")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }

    private func difficultyColor(_ level: GlossaryEntry.DifficultyLevel) -> Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }

    private func filterChip(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? color : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Entry Sheet

    @State private var newTerm = ""
    @State private var newDefinition = ""
    @State private var newExample = ""
    @State private var newTranslation = ""
    @State private var newTargetLang: TranscriptionLanguage = .spanish
    @State private var newDifficulty: GlossaryEntry.DifficultyLevel = .intermediate

    private var addEntrySheet: some View {
        NavigationView {
            Form {
                Section("Term") {
                    TextField("Term", text: $newTerm)
                    TextField("Definition", text: $newDefinition, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Example sentence", text: $newExample, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Translation") {
                    Picker("Target Language", selection: $newTargetLang) {
                        ForEach(TranscriptionLanguage.allCases, id: \.self) { lang in
                            Text("\(lang.flag) \(lang.displayName)").tag(lang)
                        }
                    }
                    TextField("Translation", text: $newTranslation)
                }

                Section("Difficulty") {
                    Picker("Level", selection: $newDifficulty) {
                        ForEach(GlossaryEntry.DifficultyLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Term")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let orgId = orgService.currentOrganization?.id else { return }
                        let entry = GlossaryEntry(
                            organizationId: orgId,
                            term: newTerm,
                            definition: newDefinition,
                            example: newExample,
                            targetLanguage: newTargetLang,
                            translation: newTranslation,
                            difficulty: newDifficulty
                        )
                        orgService.addGlossaryEntry(entry)
                        newTerm = ""
                        newDefinition = ""
                        newExample = ""
                        newTranslation = ""
                        showAddEntry = false
                    }
                    .disabled(newTerm.isEmpty || newDefinition.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    NavigationView { GlossaryView() }
}
