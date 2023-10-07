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

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            AlbumView(currentAlbum: nil)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(currentAlbum: album)
                    default: Color.clear
                    }
                })
        }
        .navigationTransition(.default, interactivity: .pan)
    }
}
