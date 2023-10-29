//
//  IllustrationMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftData
import SwiftUI

struct IllustrationMoveMenu: View {

    @Environment(\.modelContext) var modelContext

    var illustrations: [Illustration]
    var containingAlbum: Album?
    var onMoved: () -> Void

    var body: some View {
        if containingAlbum != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    await actor.removeFromAlbum(illustrations)
                    onMoved()
                }
            }
        }
        if let containingAlbum, let parentAlbum = containingAlbum.parentAlbum {
            Button {
                Task {
                    let illustrationPersistentModelIDs = illustrations.map { $0.persistentModelID }
                    await actor.addIllustrations(withIdentifiers: illustrationPersistentModelIDs,
                                                 toAlbumWithIdentifier: parentAlbum.persistentModelID)
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
            ForEach(albumsThatIllustrationsCanBeMovedTo()) { album in
                Button {
                    Task {
                        let illustrationPersistentModelIDs = illustrations.map { $0.persistentModelID }
                        await actor.addIllustrations(withIdentifiers: illustrationPersistentModelIDs,
                                                     toAlbumWithIdentifier: album.persistentModelID)
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
    }

    func albumsThatIllustrationsCanBeMovedTo() -> [Album] {
        if let containingAlbum {
            return containingAlbum.albums()
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
