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

                Text("How Lecsy Handles Your Audio")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    privacyPoint(
                        icon: "iphone",
                        text: "Your recordings stay on your device. Transcription runs on your iPhone."
                    )
                    privacyPoint(
                        icon: "cloud.slash",
                        text: "Lecsy never uploads your audio. Only transcript text can be saved to your account — and only if you choose to."
                    )
                    privacyPoint(
                        icon: "building.2",
                        text: "If your organization enables cloud transcription, audio is processed transiently by our subprocessor and is never stored by Lecsy."
                    )
                    privacyPoint(
                        icon: "lock.shield",
                        text: "Your content is yours. We never train AI models on your data."
                    )
                }
                .padding(.horizontal, 24)

                if let url = URL(string: "https://lecsy.app/privacy") {
                    Link("Read our Privacy Policy", destination: url)
                        .font(.subheadline)
                }

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
    AIConsentView { }
}
