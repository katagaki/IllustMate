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

    var body: some View {
        NavigationStack(path: $viewPath) {
            AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                      currentAlbum: album,
                      displayedIllustration: $displayedIllustration)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                                                      currentAlbum: album,
                                                      displayedIllustration: $displayedIllustration)
                    default: Color.clear
                    }
                })
        }
        .overlay {
            if let displayedIllustration {
                IllustrationViewer(namespace: illustrationTransitionNamespace,
                                   illustration: displayedIllustration) {
                    withAnimation(.snappy.speed(2)) {
                        self.displayedIllustration = nil
                    }
                }
            }
        }
    }
}
