//
//  TitleInputSheet.swift
//  lecsy
//
//  Created on 2026/02/19.
//

import SwiftUI

struct TitleInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var courseName: String = ""
    @State private var showCourseSuggestions = false
    let existingCourses: [String]
    let onSave: (String, String?) -> Void

    init(defaultTitle: String, onSave: @escaping (String, String?) -> Void) {
        _title = State(initialValue: defaultTitle)
        self.existingCourses = LectureStore.shared.allCourseNames()
        self.onSave = onSave
    }

    var filteredCourses: [String] {
        if courseName.isEmpty { return existingCourses }
        return existingCourses.filter { $0.localizedCaseInsensitiveContains(courseName) }
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

                    TextField("Course (optional)", text: $courseName)
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

    private func save() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCourse = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            finalTitle.isEmpty ? defaultTitle() : finalTitle,
            finalCourse.isEmpty ? nil : finalCourse
        )
        dismiss()
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return "Lecture \(formatter.string(from: Date()))"
    }
}
