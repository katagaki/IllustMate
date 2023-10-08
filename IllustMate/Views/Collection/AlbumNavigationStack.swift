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

    var body: some View {
        NavigationStack(path: $viewPath) {
            AlbumView(currentAlbum: album)
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(currentAlbum: album)
                    default: Color.clear
                    }
                })
        }
    }
}
