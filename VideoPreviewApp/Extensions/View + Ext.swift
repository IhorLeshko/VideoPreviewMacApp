//
//  View + Ext.swift
//  VideoPreviewApp
//
//  Created by Ihor on 05/04/2025.
//

import SwiftUI

extension View {
    func toast(message: String?) -> some View {
        self.modifier(ToastModifier(message: message ?? ""))
    }
}
