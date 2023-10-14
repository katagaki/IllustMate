//
//  AlbumMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/14.
//

import SwiftData
import SwiftUI

struct AlbumMoveMenu: View {

    @Environment(\.modelContext) var modelContext
    var album: Album
    var onMoved: () -> Void

    var body: some View {
        if album.parentAlbum != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                album.removeFromAlbum()
                onMoved()
            }
        }
        if let parentAlbum = album.parentAlbum?.parentAlbum {
            Button {
                parentAlbum.addChildAlbum(album)
                onMoved()
            } label: {
                Label(
                    title: { Text("Shared.MoveOutTo.\(parentAlbum.name)") },
                    icon: { Image(uiImage: parentAlbum.cover()) }
                )
            }
        }
        Menu("Shared.AddToAlbum", systemImage: "tray.and.arrow.down") {
            ForEach(albumsThatAlbumCanBeMovedTo()) { albumToMoveTo in
                Button {
                    albumToMoveTo.addChildAlbum(album)
                    onMoved()
                } label: {
                    Label(
                        title: { Text(albumToMoveTo.name) },
                        icon: { Image(uiImage: albumToMoveTo.cover()) }
                    )
                }
            }
        }
    }

    func albumsThatAlbumCanBeMovedTo() -> [Album] {
        if let parentAlbum = album.parentAlbum {
            return parentAlbum.albums().filter({ $0.id != album.id })
        } else {
            do {
                return try modelContext.fetch(FetchDescriptor<Album>(
                    predicate: #Predicate { $0.parentAlbum == nil },
                    sortBy: [SortDescriptor(\.name)]))
            } catch {
                debugPrint(error.localizedDescription)
                return []
            }
        }
    }
}
