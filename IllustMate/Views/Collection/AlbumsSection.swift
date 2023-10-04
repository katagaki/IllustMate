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
    var albums: [Album]
    @Binding var isAddingAlbum: Bool
    @Binding var albumToRename: Album?

    let albumColumnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                                    GridItem(.flexible(), spacing: 20.0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            HStack(alignment: .center, spacing: 16.0) {
                ListSectionHeader(text: "Albums.Albums")
                Spacer()
                Button {
                    isAddingAlbum = true
                } label: {
                    Image(systemName: "rectangle.stack.badge.plus")
                }
            }
            .padding([.leading, .trailing], 20.0)
            .padding([.bottom], 6.0)
            Divider()
                .padding([.leading], 20.0)
            Group {
                if !albums.isEmpty {
                    LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
                        ForEach(albums) { album in
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
                                    albumToRename = album
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
                    }
                } else {
                    Text("Albums.NoAlbums")
                        .foregroundStyle(.secondary)
                }
            }
            .padding([.leading, .trailing, .top], 20.0)
        }
    }

    func moveIllustrationToAlbum(_ illustration: IllustrationTransferable, to album: Album) {
        let fetchDescriptor = FetchDescriptor<Illustration>(
            predicate: #Predicate<Illustration> { $0.id == illustration.id }
        )
        if let illustrations = try? modelContext.fetch(fetchDescriptor) {
            album.moveChildIllustrations(illustrations)
        }
    }
}
