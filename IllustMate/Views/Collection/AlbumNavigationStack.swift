//
//  AlbumNavigationStack.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/07.
//

import SwiftUI

struct AlbumNavigationStack: View {

    var album: Album
    @State var viewPath: [ViewPath] = []

    @Namespace var illustrationTransitionNamespace

    @State var displayedIllustration: Illustration?
    @State var illustrationDisplayOffset: CGSize = .zero

    var body: some View {
        NavigationStack(path: $viewPath) {
            AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                      currentAlbum: album,
                      displayedIllustration: $displayedIllustration,
                      illustrationDisplayOffset: $illustrationDisplayOffset)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                                                      currentAlbum: album,
                                                      displayedIllustration: $displayedIllustration,
                                                      illustrationDisplayOffset: $illustrationDisplayOffset)
                    default: Color.clear
                    }
                })
        }
        .overlay {
            if let displayedIllustration {
                IllustrationViewer(namespace: illustrationTransitionNamespace,
                                   illustration: displayedIllustration,
                                   illustrationDisplayOffset: $illustrationDisplayOffset) {
                    withAnimation(.snappy.speed(2)) {
                        self.displayedIllustration = nil
                    } completion: {
                        illustrationDisplayOffset = .zero
                    }
                }
            }
        }
    }
}
