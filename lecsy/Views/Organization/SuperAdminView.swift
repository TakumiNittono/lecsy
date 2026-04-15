//
//  SuperAdminView.swift
//  lecsy
//
//  Super-admin only screen for creating organizations and granting ownership.
//  Visible only when SupabaseClient.shared.userEmail is in the super_admin_emails table.
//

import SwiftUI

@MainActor
struct SuperAdminView: View {
    @State private var orgs: [OrgRow] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var grantTarget: OrgRow?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Create new organization", systemImage: "plus.circle.fill")
                    }
                }

                Section("All organizations (\(orgs.count))") {
                    if loading {
                        ProgressView()
                    } else if orgs.isEmpty {
                        Text("No organizations yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(orgs) { org in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(org.name).font(.headline)
                                HStack(spacing: 8) {
                                    Text(org.slug).font(.caption).foregroundStyle(.secondary)
                                    if let plan = org.plan {
                                        Text(plan.uppercased())
                                            .font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(.blue.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    if let seats = org.max_seats {
                                        Text("\(seats) seats").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                Button {
                                    grantTarget = org
                                } label: {
                                    Label("Grant owner", systemImage: "crown.fill")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Super Admin")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showCreateSheet) {
                CreateOrgSheet { newOrg in
                    orgs.insert(newOrg, at: 0)
                }
            }
            .sheet(item: $grantTarget) { org in
                GrantOwnershipSheet(org: org)
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            orgs = try await OrganizationAPI.shared.listAllOrganizations()
            errorMessage = nil
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }
}

@MainActor
private struct CreateOrgSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: (OrgRow) -> Void

    @State private var name = ""
    @State private var slug = ""
    @State private var type = "language_school"
    @State private var plan = "pro"
    @State private var maxSeats = 50
    @State private var ownerEmail = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Organization") {
                    TextField("Name", text: $name)
                    TextField("Slug (lowercase, hyphens)", text: $slug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Type", selection: $type) {
                        Text("Language school").tag("language_school")
                        Text("University IEP").tag("university_iep")
                        Text("College").tag("college")
                        Text("Corporate").tag("corporate")
                    }
                    Picker("Plan", selection: $plan) {
                        Text("Free").tag("free")
                        Text("Pro").tag("pro")
                    }
                    Stepper("Max seats: \(maxSeats)", value: $maxSeats, in: 5...10000, step: 5)
                }

                Section("First owner (optional)") {
                    TextField("owner@school.edu", text: $ownerEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if submitting { ProgressView() } else { Text("Create organization") }
                    }
                    .disabled(name.isEmpty || slug.isEmpty || submitting)
                }
            }
            .navigationTitle("New organization")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        do {
            let payload = OrganizationAPI.CreateOrgPayload(
                name: name,
                slug: slug.lowercased(),
                type: type,
                plan: plan,
                max_seats: maxSeats,
                owner_email: ownerEmail.isEmpty ? nil : ownerEmail.lowercased()
            )
            let org = try await OrganizationAPI.shared.createOrganization(payload)
            onCreated(org)
            dismiss()
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }
}

@MainActor
private struct GrantOwnershipSheet: View {
    @Environment(\.dismiss) private var dismiss
    let org: OrgRow
    @State private var email = ""
    @State private var submitting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Grant owner permission to") {
                    Text(org.name).font(.headline)
                    TextField("owner@school.edu", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                if let resultMessage {
                    Section { Text(resultMessage).foregroundStyle(.green) }
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if submitting { ProgressView() } else { Text("Grant ownership") }
                    }
                    .disabled(email.isEmpty || submitting)
                }
            }
            .navigationTitle("Grant ownership")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        do {
            let r = try await OrganizationAPI.shared.grantOwnership(orgId: org.id, email: email)
            resultMessage = "Owner \(r.action). The user will become active on next login."
            errorMessage = nil
        } catch {
            errorMessage = ErrorMessages.friendly(error)
            resultMessage = nil
        }
    }
}
