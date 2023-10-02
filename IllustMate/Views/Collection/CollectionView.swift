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
    @Query(sort: \Album.name,
           order: .forward,
           animation: .snappy.speed(2)) var albums: [Album]
    @Query(sort: \Illustration.dateAdded,
           order: .forward,
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    @State var isAddingAlbum: Bool = false
    @State var isSelectingIllustrations: Bool = false

    let albumColumnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                                    GridItem(.flexible(), spacing: 20.0)]
    let illustrationsColumnConfiguration = [GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0)]

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            ScrollView(.vertical) {
                // Albums
                HStack(alignment: .center, spacing: 8.0) {
                    ListSectionHeader(text: "Albums.Albums")
                    Spacer()
                    Button {
                        isAddingAlbum = true
                    } label: {
                        Image(systemName: "rectangle.stack.badge.plus")
                    }
                }
                .padding([.leading, .trailing, .top], 20.0)
                Divider()
                    .padding([.leading], 20.0)
                Group {
                    if rootHasAlbums() {
                        LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
                            ForEach(albums) { album in
                                if album.parentAlbum == nil {
                                    albumItem(album)
                                }
                            }
                        }
                    } else {
                        Text("Albums.NoAlbums")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.leading, .trailing], 20.0)
                .padding([.top], 12.0)
                // Illustrations
                HStack(alignment: .center, spacing: 8.0) {
                    ListSectionHeader(text: "Albums.Illustrations")
                    Spacer()
                    Button {
                        withAnimation(.snappy.speed(2)) {
                            isSelectingIllustrations.toggle()
                        }
                    } label: {
                        Text("Shared.Select")
                            .padding([.leading, .trailing], 8.0)
                            .padding([.top, .bottom], 4.0)
                            .foregroundStyle(isSelectingIllustrations ? .white : .accent)
                            .background(isSelectingIllustrations ? .accent : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 99))
                    }
                }
                .padding([.leading, .trailing, .top], 20.0)
                Group {
                    if rootHasIllustrations() {
                        LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                            ForEach(illustrations) { illustration in
                                if let albums = illustration.containingAlbums, albums.isEmpty {
                                    illustrationItem(illustration)
                                }
                            }
                        }
                    } else {
                        Divider()
                            .padding([.leading], 20.0)
                        Text("Albums.NoIllustrations")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.bottom], 20.0)
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .album(let album): AlbumView(currentAlbum: album)
                case .illustrationViewer(let illustration): IllustrationViewerView(illustration: illustration)
                }
            })
            .sheet(isPresented: $isAddingAlbum) {
                NewAlbumView(albumToAddTo: nil)
            }
            .navigationTitle("ViewTitle.Collection")
        }
    }

    func rootHasAlbums() -> Bool {
        return !albums.filter({ $0.parentAlbum == nil }).isEmpty
    }

    func rootHasIllustrations() -> Bool {
        return !illustrations.filter({ illustration in
            if let album = illustration.containingAlbums {
                return album.isEmpty
            }
            return true
        }).isEmpty
    }

    @ViewBuilder
    func albumItem(_ album: Album) -> some View {
        NavigationLink(value: ViewPath.album(album: album)) {
            AlbumItem(album: album)
        }
        .contextMenu {
            Button {
                // TODO: Rename album
            } label: {
                Text("Shared.Rename")
                Image(systemName: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(album)
            } label: {
                Text("Shared.Delete")
                Image(systemName: "trash")
            }
        }
    }

    @ViewBuilder
    func illustrationItem(_ illustration: Illustration) -> some View {
        NavigationLink(value: ViewPath.illustrationViewer(illustration: illustration)) {
            IllustrationItem(illustration: illustration)
        }
        .contextMenu {
            Menu {
                ForEach(albums) { album in
                    if album.parentAlbum == nil {
                        Button {
                            album.addChildIllustration(illustration)
                        } label: {
                            Text(album.name)
                        }
                    }
                }
            } label: {
                Text("Shared.AddToAlbum")
                Image(systemName: "rectangle.stack.badge.plus")
            }
            Button(role: .destructive) {
                modelContext.delete(illustration)
            } label: {
                Text("Shared.Delete")
                Image(systemName: "trash")
            }
        }
    }

}
