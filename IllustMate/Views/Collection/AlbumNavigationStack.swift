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
            AlbumView(namespace: illustrationTransitionNamespace,
                      currentAlbum: album,
                      viewerManager: $viewerManager)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(namespace: illustrationTransitionNamespace,
                                                      currentAlbum: album,
                                                      viewerManager: $viewerManager)
                    default: Color.clear
                    }
                })
        }
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: viewerManager)
    }
}
