//
//  ReportSheet.swift
//  lecsy
//

import SwiftUI

struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportService = ReportService.shared

    @State private var selectedCategory: ReportCategory = .bug
    @State private var title = ""
    @State private var description = ""
    @State private var email = ""
    @State private var showMailError = false

    var body: some View {
        NavigationView {
            Form {
                // Category
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ReportCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                } header: {
                    Text("What's the issue?")
                }

                // Details
                Section {
                    TextField("Brief summary", text: $title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Describe the problem in detail...", text: $description, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text("Details")
                }

                // Email
                Section {
                    TextField("your@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Email (optional)")
                } footer: {
                    Text("So we can follow up with you")
                }

                // Submit
                Section {
                    Button {
                        let success = reportService.submitReport(
                            category: selectedCategory,
                            title: title.trimmingCharacters(in: .whitespaces),
                            description: description.trimmingCharacters(in: .whitespaces),
                            email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespaces)
                        )
                        if success {
                            dismiss()
                        } else {
                            showMailError = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Submit Report")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                } footer: {
                    Text("Opens your email app with the report details.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .alert("Mail Not Available", isPresented: $showMailError) {
            Button("Copy Email") {
                UIPasteboard.general.string = "support@lecsy.app"
                dismiss()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Mail app is not configured. You can email us at support@lecsy.app")
        }
    }

    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty
    }
}

#Preview {
    ReportSheet()
}
