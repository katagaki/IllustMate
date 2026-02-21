//
//  AlbumMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/14.
//

import SwiftUI

struct AlbumMoveMenu: View {

    var album: Album
    var onMoved: () -> Void

    @State var availableAlbums: [Album] = []
    @State var parentAlbum: Album? = nil
    @State var grandparentAlbum: Album? = nil

    var body: some View {
        if album.parentAlbumID != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    await actor.removeParentAlbum(forAlbumWithidentifier: album.id)
                    onMoved()
                }
            }
        }
        if let grandparentAlbum {
            Button {
                Task {
                    await actor.addAlbum(withID: album.id,
                                         toAlbumWithID: grandparentAlbum.id)
                    onMoved()
                }
            } label: {
                Label(
                    title: { Text("Shared.MoveOutTo.\(grandparentAlbum.name)") },
                    icon: { Image(uiImage: grandparentAlbum.cover()) }
                )
            }
        }
        Menu("Shared.AddToAlbum", systemImage: "tray.and.arrow.down") {
            ForEach(availableAlbums) { albumToMoveTo in
                Button {
                    Task {
                        await actor.addAlbum(withID: album.id,
                                             toAlbumWithID: albumToMoveTo.id)
                        onMoved()
                    }
                } label: {
                    Label(
                        title: { Text(albumToMoveTo.name) },
                        icon: { Image(uiImage: albumToMoveTo.cover()) }
                    )
                }
            }
        }
        .task {
            await loadAlbums()
        }
    }

    func loadAlbums() async {
        if let parentAlbumID = album.parentAlbumID {
            let parent = await actor.album(for: parentAlbumID)
            parentAlbum = parent
            if let grandparentID = parent?.parentAlbumID {
                grandparentAlbum = await actor.album(for: grandparentID)
            }
            if let parent {
                availableAlbums = (try? await actor.albums(in: parent, sortedBy: .nameAscending))?.filter {
                    $0.id != album.id
                } ?? []
            }
        } else {
            availableAlbums = (try? await actor.albums(in: nil, sortedBy: .nameAscending)) ?? []
        }
    }
}
