//
//  TitleInputSheet.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import SwiftUI

struct TitleInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var orgService = OrganizationService.shared
    @State private var title: String
    @State private var courseName: String = ""
    @State private var showCourseSuggestions = false
    @State private var selectedClassId: UUID?
    let existingCourses: [String]
    let onSave: (_ title: String, _ courseName: String?, _ classId: UUID?) -> Void

    init(
        defaultTitle: String,
        onSave: @escaping (_ title: String, _ courseName: String?, _ classId: UUID?) -> Void
    ) {
        _title = State(initialValue: defaultTitle)
        self.existingCourses = LectureStore.shared.allCourseNames()
        self.onSave = onSave
    }

    var filteredCourses: [String] {
        if courseName.isEmpty { return existingCourses }
        return existingCourses.filter { $0.localizedCaseInsensitiveContains(courseName) }
    }

    /// Show the class picker only for org members whose org has at least one
    /// active class. B2C users never see it.
    private var showClassPicker: Bool {
        orgService.isInOrganization && !orgService.classes.isEmpty
    }

    private var selectedClassName: String? {
        guard let id = selectedClassId else { return nil }
        return orgService.classes.first(where: { $0.id == id })?.name
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Name your recording")
                    .font(.title3.bold())
                    .padding(.top, 24)

                VStack(spacing: 12) {
                    TextField("Lecture title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)

                    if showClassPicker {
                        classPicker
                            .frame(maxWidth: 500)
                    }

                    TextField("Subject (optional)", text: $courseName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)
                        .onChange(of: courseName) { _, newValue in
                            showCourseSuggestions = !newValue.isEmpty && !filteredCourses.isEmpty
                        }

                    if showCourseSuggestions {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filteredCourses, id: \.self) { course in
                                    Button {
                                        courseName = course
                                        showCourseSuggestions = false
                                    } label: {
                                        Text(course)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.secondary.opacity(0.12))
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else if !existingCourses.isEmpty && courseName.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(existingCourses, id: \.self) { course in
                                    Button {
                                        courseName = course
                                    } label: {
                                        Text(course)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.secondary.opacity(0.12))
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Button(action: save) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)

                Button("Skip") {
                    save()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EmptyView()
                }
            }
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    // MARK: - Class picker

    private var classPicker: some View {
        Menu {
            Button("None") { selectedClassId = nil }
            ForEach(orgService.classes) { orgClass in
                Button(orgClass.name) { selectedClassId = orgClass.id }
            }
        } label: {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text(selectedClassName ?? "Class (optional)")
                    .foregroundColor(selectedClassName == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func save() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCourse = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            finalTitle.isEmpty ? defaultTitle() : finalTitle,
            finalCourse.isEmpty ? nil : finalCourse,
            selectedClassId
        )
        dismiss()
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return "Lecture \(formatter.string(from: Date()))"
    }
}
