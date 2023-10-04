//
//  CollectionView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI
import SwiftData

struct CollectionView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @Query(filter: #Predicate<Album> { $0.parentAlbum == nil },
           sort: \Album.name,
           order: .forward,
           animation: .snappy.speed(2)) var albums: [Album]
    @Query(sort: \Illustration.dateAdded,
           order: .reverse,
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20.0) {
                    AlbumsSection(albums: albums,
                                  isAddingAlbum: $isAddingAlbum,
                                  albumToRename: $albumToRename)
                    IllustrationsSection(
                        illustrations: illustrations.filter({ $0.isInAnyAlbum() }),
                        selectableAlbums: albums,
                        isRootAlbum: true)
                }
                .padding([.top], 20.0)
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .album(let album): AlbumView(currentAlbum: album)
                case .illustrationViewer(let illustration): IllustrationViewerView(illustration: illustration)
                default: Color.clear
                }
            })
            .sheet(isPresented: $isAddingAlbum) {
                NewAlbumView(albumToAddTo: nil)
            }
            .sheet(item: $albumToRename) { album in
                RenameAlbumView(album: album)
            }
            .navigationTitle("ViewTitle.Collection")
        }
    }
}
