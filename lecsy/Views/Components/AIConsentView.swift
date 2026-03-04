//
//  AIConsentView.swift
//  lecsy
//
//  Created on 2026/03/03.
//

import SwiftUI

struct AIConsentView: View {
    var onAccept: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Privacy & On-Device AI")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    privacyPoint(
                        icon: "cpu",
                        text: "All AI transcription runs on-device using Apple CoreML. No third-party AI service is used."
                    )
                    privacyPoint(
                        icon: "iphone",
                        text: "Your audio recordings never leave your device and are never sent to any external server."
                    )
                    privacyPoint(
                        icon: "wifi",
                        text: "Internet is only used once to download the AI model (~150 MB). No user data is transmitted during the download."
                    )
                    privacyPoint(
                        icon: "icloud",
                        text: "If you sign in, only transcription text syncs to our server for cross-device access. Audio is never uploaded."
                    )
                }
                .padding(.horizontal, 24)

                Link("Read our Privacy Policy", destination: URL(string: "https://lecsy.app/privacy")!)
                    .font(.subheadline)

                Spacer()

                Button(action: onAccept) {
                    Text("Agree & Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AIConsentView {
        print("Accepted")
    }
}
