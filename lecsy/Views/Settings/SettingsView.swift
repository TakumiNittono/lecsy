//
//  SettingsView.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var authService = AuthService.shared
    
    @State private var showSignInSheet = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountErrorAlert = false
    @State private var deleteAccountErrorMessage = ""
    @State private var isDeletingAccount = false
    
    var body: some View {
        NavigationView {
            List {
                // Account section
                Section("Account") {
                    if authService.isAuthenticated {
                        if let user = authService.currentUser {
                            HStack {
                                Text("Signed in as:")
                                Spacer()
                                Text(user.email ?? "Unknown")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            Task {
                                try? await authService.signOut()
                            }
                        }
                        
                        Button(action: {
                            showDeleteAccountAlert = true
                        }) {
                            HStack {
                                if isDeletingAccount {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("Delete Account")
                            }
                        }
                        .foregroundColor(.red)
                        .disabled(isDeletingAccount)
                    } else {
                        Button("Sign In") {
                            showSignInSheet = true
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSignInSheet) {
                SignInSheet()
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        do {
                            try await authService.deleteAccount()
                        } catch {
                            deleteAccountErrorMessage = error.localizedDescription
                            showDeleteAccountErrorAlert = true
                        }
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Failed to Delete Account", isPresented: $showDeleteAccountErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountErrorMessage)
            }
        }
    }
}

struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Sign in to sync lectures with the web app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                try await authService.signInWithGoogle()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        print("🍎 SettingsView: Apple Sign In button tapped")
                        Task {
                            isLoading = true
                            errorMessage = nil
                            print("🍎 SettingsView: Starting Apple Sign In...")
                            do {
                                try await authService.signInWithApple()
                                print("🍎 SettingsView: Apple Sign In completed")
                            } catch {
                                print("🍎 SettingsView: Apple Sign In error - \(error.localizedDescription)")
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
