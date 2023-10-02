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
    @State var isSelectingIllustrations: Bool = false

    let albumColumnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                                    GridItem(.flexible(), spacing: 20.0)]
    let illustrationsColumnConfiguration = [GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0)]

    var body: some View {
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
                if currentAlbum.hasAlbums() {
                    LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
                        ForEach(currentAlbum.albums()) { album in
                            albumItem(album)
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
                if currentAlbum.hasIllustrations() {
                    LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                        ForEach(currentAlbum.illustrations()) { illustration in
                            illustrationItem(illustration)
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
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .navigationTitle(currentAlbum.name)
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
                ForEach(currentAlbum.albums()) { album in
                    Button {
                        album.addChildIllustration(illustration)
                        currentAlbum.removeChildIllustration(illustration)
                    } label: {
                        Text(album.name)
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
