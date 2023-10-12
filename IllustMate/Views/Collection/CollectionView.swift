//
//  CollectionView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import NavigationTransitions
import SwiftUI
import SwiftData

struct CollectionView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace

    @State var viewerManager = ViewerManager()

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                      currentAlbum: nil,
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
#if !targetEnvironment(macCatalyst)
        .navigationTransition(.default, interactivity: .pan)
#endif
    }
}
