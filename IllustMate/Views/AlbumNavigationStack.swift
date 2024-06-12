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
        ZStack {
            NavigationStack(path: $viewPath) {
                AlbumView(currentAlbum: album)
            }
        }
        .id(album.id)
    }
}
