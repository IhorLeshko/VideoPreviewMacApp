//
//  ToastModifier.swift
//  VideoPreviewApp
//
//  Created by Ihor on 05/04/2025.
//

import SwiftUI

struct ToastModifier: ViewModifier {
    let message: String?
    @State private var showToast = false

    func body(content: Content) -> some View {
        ZStack {
            content
            if let message, !message.isEmpty {
                VStack {
                    Spacer()
                    Text(message)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 20)
                        .padding(.bottom, 40)
                        .opacity(showToast ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: showToast)
                }
            }
        }
        .onChange(of: message) { _, _ in
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showToast = false
            }
        }
    }
}
