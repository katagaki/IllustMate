//
//  CollectionView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI
import SwiftData

struct CollectionView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace

    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationManager.collectionTabPath) {
                AlbumView(namespace: illustrationTransitionNamespace,
                          viewerManager: $viewerManager)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album):
                        AlbumView(namespace: illustrationTransitionNamespace,
                                  currentAlbum: album, viewerManager: $viewerManager)
                    default: Color.clear
                    }
                })
            }
        }
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: $viewerManager)
    }
}
