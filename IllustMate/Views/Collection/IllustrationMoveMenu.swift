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

    let actor = DataActor(modelContainer: sharedModelContainer)

    var illustrations: [Illustration]
    var containingAlbum: Album?
    var onMoved: () -> Void

    @AppStorage(wrappedValue: true, "DebugThreadSafety") var useThreadSafeLoading: Bool

    var body: some View {
        if containingAlbum != nil {
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                if useThreadSafeLoading {
                    Task.detached(priority: .userInitiated) {
                        for illustration in illustrations {
                            await actor.removeFromAlbum(illustration)
                        }
                        await MainActor.run {
                            onMoved()
                        }
                    }
                } else {
                    illustrations.forEach { illustration in
                        illustration.removeFromAlbum()
                    }
                    onMoved()
                }
            }
        }
        if let containingAlbum, let parentAlbum = containingAlbum.parentAlbum {
            Button {
                if useThreadSafeLoading {
                    Task.detached(priority: .userInitiated) {
                        for illustration in illustrations {
                            await actor.addIllustration(withIdentifier: illustration.persistentModelID,
                                                        toAlbumWithIdentifier: parentAlbum.persistentModelID)
                        }
                        await MainActor.run {
                            onMoved()
                        }
                    }
                } else {
                    parentAlbum.addChildIllustrations(illustrations)
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
                    if useThreadSafeLoading {
                        Task.detached(priority: .userInitiated) {
                            for illustration in illustrations {
                                await actor.addIllustration(withIdentifier: illustration.persistentModelID,
                                                            toAlbumWithIdentifier: album.persistentModelID)
                            }
                            await MainActor.run {
                                onMoved()
                            }
                        }
                    } else {
                        album.addChildIllustrations(illustrations)
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
