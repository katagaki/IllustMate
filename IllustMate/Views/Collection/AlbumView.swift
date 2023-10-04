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

    // Root
    @Query(filter: #Predicate<Album> { $0.parentAlbum == nil },
           sort: \Album.name,
           order: .forward,
           animation: .snappy.speed(2)) var albums: [Album]
    @Query(sort: \Illustration.dateAdded,
           order: .reverse,
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    // Selected album
    var currentAlbum: Album?

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20.0) {
                if let currentAlbum = currentAlbum {
                    AlbumsSection(currentAlbum: currentAlbum,
                                  isAddingAlbum: $isAddingAlbum,
                                  albumToRename: $albumToRename)
                    IllustrationsSection(currentAlbum: currentAlbum,
                                         selectableAlbums: currentAlbum.albums())
                } else {
                    AlbumsSection(currentAlbum: currentAlbum,
                                  isAddingAlbum: $isAddingAlbum,
                                  albumToRename: $albumToRename)
                    IllustrationsSection(currentAlbum: currentAlbum,
                                         selectableAlbums: albums)
                }
            }
            .padding([.top], 20.0)
        }
        .sheet(isPresented: $isAddingAlbum) {
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .sheet(item: $albumToRename) { album in
            RenameAlbumView(album: album)
        }
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }
}
