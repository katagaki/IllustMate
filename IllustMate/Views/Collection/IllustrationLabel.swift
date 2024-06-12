//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {

    var namespace: Namespace.ID

    var illustration: Illustration

    @State var isThumbnailReadyToPresent: Bool = false
    @State var thumbnail: Image?

    var body: some View {
        ZStack(alignment: .center) {
            Color.clear
            if isThumbnailReadyToPresent {
                Group {
                    if let thumbnail {
                        thumbnail
                            .resizable()
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24.0, height: 24.0)
                            .foregroundStyle(.primary)
                            .symbolRenderingMode(.multicolor)
                    }
                }
                .transition(.opacity.animation(.snappy.speed(2)))
            }
        }
        .background(.primary.opacity(0.05))
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(.rect)
        .task {
            // TODO: Use file coordinator in async task
            Task.detached {
                if let image = illustration.thumbnail() {
                    thumbnail = Image(uiImage: image)
                }
                isThumbnailReadyToPresent = true
            }
        }
    }
}
