//
//  AlbumsSection.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftData
import SwiftUI

struct AlbumsSection: View {

    @Environment(\.modelContext) var modelContext

    @Binding var albums: [Album]
    @Binding var currentAlbum: Album?

    @Binding var isAddingAlbum: Bool
    @Binding var albumToRename: Album?

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle") var style: ViewStyle

    let albumColumnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                                    GridItem(.flexible(), spacing: 20.0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            HStack(alignment: .center, spacing: 16.0) {
                HStack(alignment: .center, spacing: 8.0) {
                    ListSectionHeader(text: "Albums.Albums")
                    if !albums.isEmpty {
                        Text("(\(albums.count))")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.snappy.speed(2)) {
                        if style == .grid {
                            style = .list
                        } else {
                            style = .grid
                        }
                    }
                } label: {
                    switch style {
                    case .grid:
                        Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                    case .list:
                        Label("Albums.Style.List", systemImage: "list.bullet")
                    }
                }
                Button {
                    isAddingAlbum = true
                } label: {
                    Label("Shared.Create", systemImage: "plus")
                }
                .padding([.trailing], 10.0)
            }
            .padding([.leading, .trailing], 20.0)
            .padding([.bottom], 6.0)
            Divider()
                .padding([.leading], 20.0)
            if !albums.isEmpty {
                switch style {
                case .grid:
                    LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
                        ForEach(albums, id: \.id) { album in
                            NavigationLink(value: ViewPath.album(album: album)) {
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
                                    .dropDestination(for: IllustrationTransferable.self) { items, _ in
                                        for item in items {
                                            moveIllustrationToAlbum(item, to: album)
                                        }
                                        return true
                                    }
                                    .aspectRatio(1.0, contentMode: .fill)
                                    .foregroundStyle(.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 8.0))
                                    .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                                    VStack(alignment: .leading, spacing: 2.0) {
                                        Text(album.name)
                                            .foregroundStyle(.primary)
                                        Text("Albums.Detail.\(album.illustrations().count),\(album.albums().count)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu { contextMenu(album) }
                        }
                    }
                    .padding([.leading, .trailing, .top], 20.0)
                case .list:
                    LazyVStack(alignment: .leading, spacing: 0.0) {
                        ForEach(albums, id: \.id) { album in
                            NavigationLink(value: ViewPath.album(album: album)) {
                                HStack(alignment: .center, spacing: 16.0) {
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
                                    .frame(width: 30.0, height: 30.0)
                                    .clipShape(RoundedRectangle(cornerRadius: 6.0))
                                    .shadow(color: .black.opacity(0.2), radius: 2.0, x: 0.0, y: 2.0)
                                    VStack(alignment: .leading, spacing: 2.0) {
                                        Text(album.name)
                                            .foregroundStyle(.primary)
                                        Text("Albums.Detail.\(album.illustrations().count),\(album.albums().count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 11.0, height: 11.0)
                                        .foregroundStyle(.primary.opacity(0.25))
                                        .fontWeight(.bold)
                                }
                                .padding([.leading], 20.0)
                                .contentShape(Rectangle())
                                .dropDestination(for: IllustrationTransferable.self) { items, _ in
                                    for item in items {
                                        moveIllustrationToAlbum(item, to: album)
                                    }
                                    return true
                                }
                            }
                            .buttonStyle(.plain)
                            .padding([.top, .bottom], 6.0)
                            .padding([.trailing], 20.0)
                            .contextMenu { contextMenu(album) }
                            Divider()
                                .padding([.leading], 66.0)
                        }
                    }
                }
            } else {
                Text("Albums.NoAlbums")
                    .foregroundStyle(.secondary)
                    .padding([.leading, .top], 20.0)
            }
        }
    }

    @ViewBuilder
    func contextMenu(_ album: Album) -> some View {
        Button {
            albumToRename = album
        } label: {
            Label("Shared.Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            modelContext.delete(album)
        } label: {
            Label("Shared.Delete", systemImage: "trash")
        }
    }

    func moveIllustrationToAlbum(_ illustration: IllustrationTransferable, to album: Album) {
        let fetchDescriptor = FetchDescriptor<Illustration>(
            predicate: #Predicate<Illustration> { $0.id == illustration.id }
        )
        if let illustrations = try? modelContext.fetch(fetchDescriptor) {
            album.addChildIllustrations(illustrations)
        }
    }
}
