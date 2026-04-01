//
//  CopyButton.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import SwiftUI

struct CopyButton: View {
    let text: String
    @State private var copied = false
    @State private var resetTask: DispatchWorkItem?

    var body: some View {
        Button(action: {
            UIPasteboard.general.string = text
            copied = true

            // Cancel previous reset task to avoid race
            resetTask?.cancel()
            let task = DispatchWorkItem { copied = false }
            resetTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
        }) {
            HStack(spacing: 6) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "Copied" : "Copy")
            }
            .font(.body)
            .foregroundColor(.blue)
        }
    }
}

#Preview {
    CopyButton(text: "Sample text")
}
