//
//  ButtonStyleModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import SwiftUI

struct ButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
#if targetEnvironment(macCatalyst)
            .buttonStyle(.borderless)
            .tint(.primary)
#else
            .buttonStyle(.plain)
#endif
    }
}

extension View {
    func buttonStyleAdaptive() -> some View {
        modifier(ButtonStyleModifier())
    }
}
