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

    @State var displayedIllustration: Illustration?
    @State var illustrationDisplayOffset: CGSize = .zero

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            AlbumView(illustrationTransitionNamespace: illustrationTransitionNamespace,
                      currentAlbum: nil,
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
#if !targetEnvironment(macCatalyst)
        .navigationTransition(.default, interactivity: .pan)
#endif
    }
}
