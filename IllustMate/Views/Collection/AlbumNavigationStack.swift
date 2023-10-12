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

    @State var viewerManager = ViewerManager()

    var body: some View {
        NavigationStack(path: $viewPath) {
            AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                      currentAlbum: album,
                      viewerManager: $viewerManager)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                                                      currentAlbum: album,
                                                      viewerManager: $viewerManager)
                    default: Color.clear
                    }
                })
        }
        .overlay {
            if let illustration = viewerManager.displayedIllustration,
               let image = viewerManager.displayedImage {
                IllustrationViewer(namespace: illustrationTransitionNamespace,
                                   illustration: illustration,
                                   displayedImage: image) {
                    withAnimation(.snappy.speed(2)) {
                        viewerManager.removeDisplay()
                    }
                }
            }
        }
    }
}
