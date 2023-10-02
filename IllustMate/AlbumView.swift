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
    @Query(sort: \Album.name,
           order: .forward,
           animation: .snappy.speed(2)) var albums: [Album]
    @Query(sort: \Illustration.dateAdded,
           order: .forward,
           animation: .snappy.speed(2)) var illustrations: [Illustration]
    @State var currentAlbum: Album?

    @State var isAddingAlbum: Bool = false
    @State var isSelectingIllustrations: Bool = false

    let albumColumnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                                    GridItem(.flexible(), spacing: 20.0)]
    let illustrationsColumnConfiguration = [GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0)]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                // Albums
                HStack(alignment: .center, spacing: 8.0) {
                    ListSectionHeader(text: "Albums.Albums")
                    Spacer()
                    Button {
                        // TODO: Toggle view
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                }
                .padding([.leading, .trailing, .top], 20.0)
                Divider()
                    .padding([.leading], 20.0)
                LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
                    if let currentAlbum = currentAlbum {
                        ForEach(currentAlbum.albums()) { album in
                            albumItem(album)
                        }
                    } else {
                        ForEach(albums) { album in
                            if album.parentAlbum == nil {
                                albumItem(album)
                            }
                        }
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
                LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                    if let currentAlbum = currentAlbum {
                        ForEach(currentAlbum.illustrations()) { illustration in
                            illustrationItem(illustration)
                        }
                    } else {
                        ForEach(illustrations) { illustration in
                            if let albums = illustration.containingAlbums, albums.isEmpty {
                                illustrationItem(illustration)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingAlbum = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingAlbum) {
                NavigationStack {
                    NewAlbumView(albumToAddTo: currentAlbum)
                }
                .presentationDetents([.medium])
                .interactiveDismissDisabled()
            }
            .navigationTitle(currentAlbum?.name ?? NSLocalizedString("ViewTitle.Collection", comment: ""))
        }
    }

    @ViewBuilder
    func albumItem(_ album: Album) -> some View {
        NavigationLink {
            AlbumView(currentAlbum: album)
        } label: {
            VStack(alignment: .leading, spacing: 8.0) {
                Group {
                    if let coverPhotoData = album.coverPhoto,
                       let coverPhoto = UIImage(data: coverPhotoData) {
                        Image(uiImage: coverPhoto)
                            .resizable()
                    } else {
                        Image("Album.Generic")
                            .resizable()
                    }
                }
                .aspectRatio(1.0, contentMode: .fill)
                .foregroundStyle(.accent)
                .background(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8.0))
                .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(album.name)
                        .tint(.primary)
                    Text(String(album.illustrations().count))
                        .tint(.secondary)
                }
            }
        }
        .contextMenu {
            Button {
                // TODO
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
        if illustration.thumbnail.count > 0, let uiImage = UIImage(data: illustration.thumbnail) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
        } else if let uiImage = UIImage(data: illustration.data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
        }
    }

}
