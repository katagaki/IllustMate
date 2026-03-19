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
        Section {
            if containingAlbum != nil {
                Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                    Task {
                        await DataActor.shared.removeParentAlbum(forPicsWithIDs: pics.map({ $0.id }))
                        if let containingAlbum {
                            AlbumCoverCache.shared.removeImages(forAlbumID: containingAlbum.id)
                        }
                        onMoved()
                    }
                }
                Divider()
            }
        }
        Section {
            if rootAlbums.isEmpty {
                Text(verbatim: "")
            }
            ForEach(rootAlbums) { album in
                AlbumHierarchyMenuItem(
                    targetAlbum: album,
                    excludingAlbumID: containingAlbum?.id ?? ""
                ) { destinationAlbum in
                    Task {
                        await DataActor.shared.addPics(withIDs: pics.map { $0.id },
                                                       toAlbumWithID: destinationAlbum.id)
                        if let containingAlbum {
                            AlbumCoverCache.shared.removeImages(forAlbumID: containingAlbum.id)
                        }
                        AlbumCoverCache.shared.removeImages(forAlbumID: destinationAlbum.id)
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
        rootAlbums = (try? await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
    }
}
