//
//  OverlayBackgroundModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/18.
//

import SwiftUI

struct OverlayBackgroundModifier: ViewModifier {

    var opacity: Double

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content
                .background(Material.bar.opacity(opacity))
        } else {
            content
        }
    }
}

extension View {
    func overlayBackground(opacity: Double) -> some View {
        modifier(OverlayBackgroundModifier(opacity: opacity))
    }
}
