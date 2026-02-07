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
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = text
            copied = true
            
            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copied = false
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "Copied" : "Copy")
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
    }
}

#Preview {
    CopyButton(text: "Sample text")
}
