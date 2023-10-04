//
//  AlbumView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI
import SwiftData

struct AlbumView: View {

    @Environment(\.modelContext) var modelContext
    @State var currentAlbum: Album

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20.0) {
                AlbumsSection(albums: currentAlbum.albums(),
                              isAddingAlbum: $isAddingAlbum,
                              albumToRename: $albumToRename)
                IllustrationsSection(illustrations: currentAlbum.illustrations(),
                                     currentAlbum: currentAlbum,
                                     parentAlbum: currentAlbum.parentAlbum,
                                     selectableAlbums: currentAlbum.albums())
            }
            .padding([.top], 20.0)
        }
        .sheet(isPresented: $isAddingAlbum) {
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .sheet(item: $albumToRename) { album in
            RenameAlbumView(album: album)
        }
        .navigationTitle(currentAlbum.name)
    }
}
