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

    var illustrations: [PhotoIllustration]
    var containingAlbum: PhotoAlbum?
    var onMoved: () -> Void

    var body: some View {
        if let containingAlbum {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                Task {
                    try? await photosActor.removeParentAlbum(
                        forIllustrationsWithIDs: illustrations.map({ $0.id }),
                        fromAlbum: containingAlbum
                    )
                    onMoved()
                }
            }
        }
        Menu("Shared.AddToAlbum", systemImage: "tray.and.arrow.down") {
            ForEach(albumsThatIllustrationsCanBeMovedTo()) { album in
                Button {
                    Task {
                        let illustrationIDs = illustrations.map { $0.id }
                        try? await photosActor.addIllustrations(withIDs: illustrationIDs, toAlbum: album)
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
    
    func albumsThatIllustrationsCanBeMovedTo() -> [PhotoAlbum] {
        if let containingAlbum {
            return containingAlbum.childAlbums()
        } else {
            return []
        }
    }
}
