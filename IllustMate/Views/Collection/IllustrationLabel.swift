//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {

    @Environment(ConcurrencyManager.self) var concurrency
    var namespace: Namespace.ID

    var illustration: Illustration
    var isHiddenAndOverridesState: Bool

    @State var state: CloudImageState = .notReadyForDisplay
    @State var thumbnailImage: Image?

    var body: some View {
        ZStack(alignment: .center) {
            Color.clear
            if !isHiddenAndOverridesState {
                if state == .readyForDisplay {
                    if let thumbnailImage {
                        thumbnailImage
                            .resizable()
                            .transition(.opacity.animation(.snappy.speed(2)))
                            .matchedGeometryEffect(id: illustration.id, in: namespace)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24.0, height: 24.0)
                            .foregroundStyle(.primary)
                            .symbolRenderingMode(.multicolor)
                            .matchedGeometryEffect(id: illustration.id, in: namespace)
                    }
                }
            }
        }
        .background(.primary.opacity(0.05))
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(.rect)
        .task {
            switch state {
            case .notReadyForDisplay:
                state = .downloading
                concurrency.queue.addOperation {
                    if let image = illustration.thumbnail() {
                        thumbnailImage = Image(uiImage: image)
                    }
                    state = .readyForDisplay
                }
            default: break
            }
        }
    }
}
