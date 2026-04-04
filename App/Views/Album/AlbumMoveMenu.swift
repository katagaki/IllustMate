//
//  AlbumMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/14.
//

import SwiftUI

struct AlbumMoveMenu: View {

    var album: Album
    var totalAlbumCount: Int
    var onMoved: () -> Void

    @State var rootAlbums: [Album] = []

    var body: some View {
        if album.parentAlbumID != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    await DataActor.shared.removeParentAlbum(forAlbumWithidentifier: album.id)
                    onMoved()
                }
            }
        }
        Menu("Shared.MoveTo", systemImage: "tray.and.arrow.down") {
            if rootAlbums.isEmpty {
                Text(verbatim: "")
            }
            ForEach(rootAlbums) { rootAlbum in
                AlbumHierarchyMenuItem(
                    targetAlbum: rootAlbum,
                    excludingAlbumID: album.id
                ) { destinationAlbum in
                    Task {
                        await DataActor.shared.addAlbum(withID: album.id,
                                             toAlbumWithID: destinationAlbum.id)
                        onMoved()
                    }
                }
            }
        }
        .disabled(totalAlbumCount == 0)
        .task {
            await loadAlbums()
        }
    }

    func loadAlbums() async {
        rootAlbums = (try? await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
    }
}

struct AlbumHierarchyMenuItem: View {

    var targetAlbum: Album
    var excludingAlbumID: String
    var onSelect: (Album) -> Void

    @State var childAlbums: [Album]?

    var isExcluded: Bool {
        targetAlbum.id == excludingAlbumID
    }

    var body: some View {
        if let children = childAlbums {
            if !children.isEmpty {
                Menu(targetAlbum.name) {
                    if !isExcluded {
                        Button("Shared.MoveHere", systemImage: "tray.and.arrow.down") {
                            onSelect(targetAlbum)
                        }
                        Divider()
                    }
                    ForEach(children) { child in
                        AlbumHierarchyMenuItem(
                            targetAlbum: child,
                            excludingAlbumID: excludingAlbumID,
                            onSelect: onSelect
                        )
                    }
                }
            } else if !isExcluded {
                Button(targetAlbum.name) {
                    onSelect(targetAlbum)
                }
            }
        } else {
            Button(targetAlbum.name) {
                if !isExcluded { onSelect(targetAlbum) }
            }
            .task {
                await loadChildAlbums()
            }
        }
    }

    func loadChildAlbums() async {
        childAlbums = (try? await DataActor.shared.albumsWithCounts(in: targetAlbum, sortedBy: .nameAscending)) ?? []
    }
}
