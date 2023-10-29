//
//  OptionalImage.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/10.
//

import SwiftUI

struct OptionalImage: View {

    var imageData: Data?

    var body: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .toggledTransition(.opacity.animation(.snappy.speed(2)))
        } else {
            Rectangle()
                .foregroundStyle(.primary.opacity(0.1))
        }
    }
}
