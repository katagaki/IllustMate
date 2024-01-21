//
//  View.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/28.
//

import SwiftUI

extension View {
    @MainActor func render(scale displayScale: CGFloat = 1.0) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = displayScale
        return renderer.uiImage
    }
}
