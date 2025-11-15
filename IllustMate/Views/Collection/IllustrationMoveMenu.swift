//
//  IllustrationMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftData
import SwiftUI

struct IllustrationMoveMenu: View {

    @Environment(\.modelContext) private var modelContext
    
    var illustrations: [Illustration]
    var containingAlbum: Album?
    var onMoved: () -> Void

    @State private var albumsToMoveTo: [Album] = []

    var body: some View {
        if containingAlbum != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    await actor.removeParentAlbum(forIllustrationsWithIDs: illustrations.map({ $0.persistentModelID }))
                    onMoved()
                }
            }
        }
        if let containingAlbum, let parentAlbum = containingAlbum.parentAlbum {
            Button {
                Task {
                    let illustrationPersistentModelIDs = illustrations.map { $0.persistentModelID }
                    await actor.addIllustrations(withIDs: illustrationPersistentModelIDs,
                                                 toAlbumWithID: parentAlbum.persistentModelID)
                    onMoved()
                }
            } label: {
                Label(
                    title: { Text("Shared.MoveOutTo.\(parentAlbum.name)") },
                    icon: { Image(uiImage: parentAlbum.cover()) }
                )
            }
        }
        Menu("Shared.AddToAlbum", systemImage: "tray.and.arrow.down") {
            ForEach(albumsToMoveTo) { album in
                Button {
                    Task {
                        let illustrationPersistentModelIDs = illustrations.map { $0.persistentModelID }
                        await actor.addIllustrations(withIDs: illustrationPersistentModelIDs,
                                                     toAlbumWithID: album.persistentModelID)
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
            await loadAlbumsToMoveTo()
        }
    }

    func loadAlbumsToMoveTo() async {
        if let containingAlbum {
            albumsToMoveTo = containingAlbum.albums()
        } else {
            do {
                let albumIDs = try await actor.albumIDsWithNilParent()
                await MainActor.run {
                    albumsToMoveTo = albumIDs.compactMap { modelContext[$0, as: Album.self] }
                }
            } catch {
                debugPrint(error.localizedDescription)
                albumsToMoveTo = []
            }
        }
    }
}
