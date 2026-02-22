//
//  IllustrationMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct IllustrationMoveMenu: View {

    var illustrations: [Illustration]
    var containingAlbum: Album?
    var onMoved: () -> Void

    @State var availableAlbums: [Album] = []
    @State var parentAlbum: Album?

    var body: some View {
        if containingAlbum != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    await actor.removeParentAlbum(forIllustrationsWithIDs: illustrations.map({ $0.id }))
                    onMoved()
                }
            }
        }
        if let containingAlbum, let parentAlbum {
            Button {
                Task {
                    await actor.addIllustrations(withIDs: illustrations.map { $0.id },
                                                 toAlbumWithID: parentAlbum.id)
                    onMoved()
                }
            } label: {
                Label(
                    title: { Text("Shared.MoveOutTo.\(parentAlbum.name)") },
                    icon: { Image(uiImage: parentAlbum.cover()) }
                )
            }
            .task(id: containingAlbum.id) {
                if let parentAlbumID = containingAlbum.parentAlbumID {
                    self.parentAlbum = await actor.album(for: parentAlbumID)
                }
            }
        }
        Menu("Shared.AddToAlbum", systemImage: "tray.and.arrow.down") {
            ForEach(availableAlbums) { album in
                Button {
                    Task {
                        await actor.addIllustrations(withIDs: illustrations.map { $0.id },
                                                     toAlbumWithID: album.id)
                        onMoved()
                    }
                } label: {
                    Label(
                        title: { Text(album.name) },
                        icon: { Image(uiImage: album.cover()) }
                    )
                }
            }
        }
        .task {
            await loadAlbums()
        }
    }

    func loadAlbums() async {
        if let containingAlbum {
            availableAlbums = (try? await actor.albumsWithCounts(in: containingAlbum, sortedBy: .nameAscending)) ?? []
        } else {
            availableAlbums = (try? await actor.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
        }
    }
}
