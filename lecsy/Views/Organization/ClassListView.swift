//
//  ClassListView.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import SwiftUI

struct ClassListView: View {
    @StateObject private var orgService = OrganizationService.shared
    @State private var showAddClass = false
    @State private var newClassName = ""
    @State private var newClassLanguage: TranscriptionLanguage = .english
    @State private var newClassSemester = "Spring 2026"

    var body: some View {
        List {
            if orgService.classes.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No classes yet")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Create classes to organize students and track progress.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(orgService.classes) { orgClass in
                    classRow(orgClass)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        orgService.removeClass(orgService.classes[index])
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Classes")
        .toolbar {
            if orgService.currentRole?.canManageClasses == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddClass = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddClass) {
            addClassSheet
        }
    }

    private func classRow(_ orgClass: OrganizationClass) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(.indigo)
                Text(orgClass.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }

            HStack(spacing: 12) {
                Label(orgClass.language.displayName, systemImage: "globe")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)

                Label(orgClass.semester, systemImage: "calendar")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)

                Label("\(orgClass.studentIds.count) students", systemImage: "person.2")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Teacher name
            if let teacherId = orgClass.teacherId,
               let teacher = orgService.members.first(where: { $0.id == teacherId || $0.userId == teacherId }) {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 10))
                    Text(teacher.displayName)
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundColor(.teal)
            }
        }
        .padding(.vertical, 4)
    }

    private var addClassSheet: some View {
        NavigationView {
            Form {
                Section("Class Info") {
                    TextField("Class name", text: $newClassName)
                    Picker("Language", selection: $newClassLanguage) {
                        ForEach(TranscriptionLanguage.allCases, id: \.self) { lang in
                            Text("\(lang.flag) \(lang.displayName)").tag(lang)
                        }
                    }
                    TextField("Semester", text: $newClassSemester)
                }
            }
            .navigationTitle("New Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddClass = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        orgService.addClass(name: newClassName, language: newClassLanguage, semester: newClassSemester)
                        newClassName = ""
                        showAddClass = false
                    }
                    .disabled(newClassName.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationView { ClassListView() }
}
