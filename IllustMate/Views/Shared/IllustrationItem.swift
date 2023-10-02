//
//  IllustrationItem.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import SwiftUI

struct IllustrationItem: View {

    var illustration: Illustration
    @State var image: UIImage?
    @State var isInitialLoadCompleted: Bool = false

    var body: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
                .transition(.opacity.animation(.snappy.speed(2)))
        } else {
            if !isInitialLoadCompleted {
                Rectangle()
                    .foregroundStyle(.clear)
                    .aspectRatio(1.0, contentMode: .fill)
                    .overlay {
                        ZStack(alignment: .center) {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                    .task {
                        if let uiImage = UIImage(data: illustration.thumbnail) {
                            image = uiImage
                        }
                        isInitialLoadCompleted = true
                    }
            } else {
                Rectangle()
                    .foregroundStyle(.clear)
                    .aspectRatio(1.0, contentMode: .fill)
                    .overlay {
                        Image(systemName: "xmark.octagon.fill")
                            .symbolRenderingMode(.hierarchical)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28.0, height: 28.0)
                            .tint(.secondary)
                    }
            }
        }
    }
}
