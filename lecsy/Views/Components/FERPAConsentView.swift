//
//  FERPAConsentView.swift
//  lecsy
//
//  Shown once per org to students after they join an organization (language
//  school, IEP, community college). The timestamp is written to
//  organization_members.ferpa_consented_at so the org's director can produce
//  FERPA compliance evidence for their administration.
//
//  Distinct from AIConsentView: that covers the general app privacy posture
//  for every user; this covers the org-scoped, education-context agreement.
//

import SwiftUI

struct FERPAConsentView: View {
    let orgName: String
    var onAccept: () -> Void

    @State private var isSubmitting = false
    @State private var showError = false
    @State private var retryCount = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Recording in \(orgName)")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Before you record a class, please acknowledge how Lecsy handles your lecture content.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 14) {
                    point(
                        icon: "person.crop.circle",
                        text: "Your recordings are tied to your account in \(orgName). Teachers and admins in your school can see your usage summary."
                    )
                    point(
                        icon: "iphone",
                        text: "Audio stays on your device. Only the transcript text is stored in your organization's Lecsy workspace."
                    )
                    point(
                        icon: "lock.shield",
                        text: "Lecsy does not sell your data and does not train AI models on it. FERPA-aligned handling applies."
                    )
                    point(
                        icon: "envelope",
                        text: "You can withdraw consent any time by emailing your school admin or privacy@lecsy.app."
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: handleAccept) {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Recording…" : "Agree & Continue")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Student Consent")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn't record consent", isPresented: $showError) {
                Button("Try Again") { handleAccept() }
                Button("Continue Offline", role: .cancel) { skipForNow() }
            } message: {
                Text("Your network looks unstable. Try again, or continue — we'll re-check next time you sign in.")
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled()
    }

    private func handleAccept() {
        guard let orgId = FERPAConsentService.shared.pendingPromptOrgId else {
            onAccept()
            return
        }
        isSubmitting = true
        Task {
            let ok = await FERPAConsentService.shared.recordConsent(orgId: orgId)
            isSubmitting = false
            if ok {
                onAccept()
            } else {
                retryCount += 1
                showError = true
            }
        }
    }

    /// Lets the student proceed when the consent PATCH keeps failing on flaky
    /// classroom wifi. We mark the prompt as dismissed for this device so the
    /// sheet doesn't re-trigger on every record attempt; the next sign-in
    /// re-runs `refreshConsentStatus` and re-prompts if the server still has
    /// no timestamp. This keeps the pilot moving without losing audit trail.
    private func skipForNow() {
        FERPAConsentService.shared.dismissPromptForSession()
        onAccept()
    }

    private func point(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    FERPAConsentView(orgName: "UF ELI") { }
}
