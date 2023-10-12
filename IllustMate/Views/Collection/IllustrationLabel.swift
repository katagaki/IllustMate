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

    @State var state: CloudImageState = .notReadyForDisplay
    @State var thumbnailImage: UIImage?

    var body: some View {
        ZStack(alignment: .center) {
            Color.clear
            if state == .readyForDisplay {
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .transition(.opacity.animation(.snappy.speed(2)))
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24.0, height: 24.0)
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.multicolor)
                }
            }
        }
        .background(.primary.opacity(0.05))
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(Rectangle())
        .task {
            switch state {
            case .notReadyForDisplay:
                state = .downloading
                concurrency.queue.addOperation {
                    if let image = illustration.thumbnail() {
                        thumbnailImage = image
                    }
                    state = .readyForDisplay
                }
            default: break
            }
        }
        .onAppear {
            if state == .hidden {
                state = .readyForDisplay
            }
        }
        .onDisappear {
            if state == .readyForDisplay {
                state = .hidden
            }
        }
    }
}
