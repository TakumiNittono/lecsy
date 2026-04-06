//
//  MemberListView.swift
//  lecsy
//
//  Created on 2026/04/05.
//

import SwiftUI

struct MemberListView: View {
    @StateObject private var orgService = OrganizationService.shared
    @State private var showAddMember = false
    @State private var newEmail = ""
    @State private var newName = ""
    @State private var newRole: OrganizationRole = .student
    @State private var searchText = ""
    @State private var filterRole: OrganizationRole?

    private var filteredMembers: [OrganizationMember] {
        var result = orgService.members
        if let role = filterRole {
            result = result.filter { $0.role == role }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.email.lowercased().contains(query)
            }
        }
        return result.sorted { a, b in
            if a.role != b.role { return a.role > b.role }
            return a.displayName < b.displayName
        }
    }

    var body: some View {
        List {
            // Summary
            Section {
                HStack(spacing: 16) {
                    summaryPill(count: orgService.activeMembers.count, label: "Active", color: .green)
                    summaryPill(count: orgService.pendingMembers.count, label: "Pending", color: .orange)
                    summaryPill(count: orgService.teacherCount, label: "Teachers", color: .blue)
                    summaryPill(count: orgService.studentCount, label: "Students", color: .purple)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            // Role filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "All", isSelected: filterRole == nil) {
                            filterRole = nil
                        }
                        ForEach(OrganizationRole.allCases, id: \.self) { role in
                            filterChip(title: role.displayName, isSelected: filterRole == role) {
                                filterRole = filterRole == role ? nil : role
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Members
            Section {
                ForEach(filteredMembers) { member in
                    memberRow(member)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if orgService.currentRole?.canManageMembers == true && member.id != orgService.currentMembership?.id {
                                Button(role: .destructive) {
                                    orgService.removeMember(member)
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if member.status == .pending && orgService.currentRole?.canManageMembers == true {
                                Button {
                                    orgService.activateMember(member)
                                } label: {
                                    Label("Activate", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                }
            } header: {
                Text("\(filteredMembers.count) members")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search members")
        .navigationTitle("Members")
        .toolbar {
            if orgService.currentRole?.canManageMembers == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddMember = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMember) {
            addMemberSheet
        }
    }

    // MARK: - Member Row

    private func memberRow(_ member: OrganizationMember) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor(for: member.role).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(avatarColor(for: member.role))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    if member.status == .pending {
                        Text("PENDING")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(member.email)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: member.role.icon)
                    .font(.system(size: 10))
                Text(member.role.displayName)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
            .foregroundColor(avatarColor(for: member.role))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(avatarColor(for: member.role).opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func avatarColor(for role: OrganizationRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .blue
        case .teacher: return .teal
        case .student: return .indigo
        }
    }

    private func summaryPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Member Sheet

    private var addMemberSheet: some View {
        NavigationView {
            Form {
                Section("Member Info") {
                    TextField("Email address", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Display name", text: $newName)
                        .textContentType(.name)
                }

                Section("Role") {
                    Picker("Role", selection: $newRole) {
                        ForEach(OrganizationRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                            Label(role.displayName, systemImage: role.icon)
                                .tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Text("The member will be added with 'pending' status. When they log into Lecsy with this email, they will automatically join the organization.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMember = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newName.isEmpty ? newEmail.components(separatedBy: "@").first ?? newEmail : newName
                        orgService.addMember(email: newEmail, displayName: name, role: newRole)
                        newEmail = ""
                        newName = ""
                        newRole = .student
                        showAddMember = false
                    }
                    .disabled(newEmail.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationView {
        MemberListView()
    }
}
