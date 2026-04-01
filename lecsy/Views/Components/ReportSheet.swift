//
//  ReportSheet.swift
//  lecsy
//

import SwiftUI

struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportService = ReportService.shared
    @StateObject private var authService = AuthService.shared

    @State private var selectedCategory: ReportCategory = .bug
    @State private var title = ""
    @State private var description = ""
    @State private var email = ""
    @State private var showSuccess = false
    @State private var errorMessage: String?

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

                // Email (only if not signed in)
                if !authService.isAuthenticated {
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
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // Submit
                Section {
                    Button {
                        submitReport()
                    } label: {
                        HStack {
                            Spacer()
                            if reportService.isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                            }
                            Text(reportService.isSubmitting ? "Sending..." : "Submit Report")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || reportService.isSubmitting)
                } footer: {
                    Text("Device info and app version will be included automatically.")
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
            .alert("Report Sent", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your feedback! We'll look into it.")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty
    }

    private func submitReport() {
        errorMessage = nil
        Task {
            do {
                try await reportService.submitReport(
                    category: selectedCategory,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespaces)
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ReportSheet()
}
