//
//  PicMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct PicMoveMenu: View {

    var pics: [Pic]
    var containingAlbum: Album?
    var onMoved: () -> Void

    @State var rootAlbums: [Album] = []

    var body: some View {
        if containingAlbum != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    await actor.removeParentAlbum(forPicsWithIDs: pics.map({ $0.id }))
                    onMoved()
                }
            }
        }
        Menu("Shared.MoveTo", systemImage: "tray.and.arrow.down") {
            ForEach(rootAlbums) { album in
                AlbumHierarchyMenuItem(
                    targetAlbum: album,
                    excludingAlbumID: containingAlbum?.id ?? ""
                ) { destinationAlbum in
                    Task {
                        await actor.addPics(withIDs: pics.map { $0.id },
                                                     toAlbumWithID: destinationAlbum.id)
                        onMoved()
                    }
                }
            }
        }
        .task {
            await loadAlbums()
        }
    }

    func loadAlbums() async {
        rootAlbums = (try? await actor.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
    }
}
