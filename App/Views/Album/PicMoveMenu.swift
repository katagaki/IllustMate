import SwiftUI

struct PicMoveMenu: View {

    var title: LocalizedStringKey
    var systemImage: String
    var pics: [Pic]
    var containingAlbum: Album?
    var totalAlbumCount: Int
    var onMoved: () -> Void
    var onOtherLibraries: () -> Void

    @State var rootAlbums: [Album] = []
    @State var lastUsedAlbum: Album?

    var body: some View {
        Menu(title, systemImage: systemImage) {
            if containingAlbum != nil {
                Section {
                    Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                        Task {
                            await DataActor.shared.removeParentAlbum(forPicsWithIDs: pics.map({ $0.id }))
                            if let containingAlbum {
                                AlbumCoverCache.shared.removeImages(forAlbumID: containingAlbum.id)
                            }
                            onMoved()
                        }
                    }
                }
            }
            if let lastUsedAlbum, lastUsedAlbum.id != containingAlbum?.id {
                Section {
                    Button(lastUsedAlbum.name, systemImage: "clock.arrow.circlepath") {
                        move(to: lastUsedAlbum)
                    }
                }
            }
            if !rootAlbums.isEmpty {
                Section {
                    ForEach(rootAlbums) { album in
                        AlbumHierarchyMenuItem(
                            targetAlbum: album,
                            excludingAlbumID: containingAlbum?.id ?? ""
                        ) { destinationAlbum in
                            move(to: destinationAlbum)
                        }
                    }
                }
            }
            Section {
                Button("Shared.MoveToOtherLibrary", systemImage: "square.stack.3d.up") {
                    onOtherLibraries()
                }
            }
        }
        .task {
            await loadAlbums()
        }
    }

    func move(to destinationAlbum: Album) {
        Task {
            await DataActor.shared.addPics(withIDs: pics.map { $0.id },
                                           toAlbumWithID: destinationAlbum.id)
            if let containingAlbum {
                AlbumCoverCache.shared.removeImages(forAlbumID: containingAlbum.id)
            }
            AlbumCoverCache.shared.removeImages(forAlbumID: destinationAlbum.id)
            LastUsedAlbum.set(destinationAlbum.id)
            onMoved()
        }
    }

    func loadAlbums() async {
        rootAlbums = (try? await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
        if let id = LastUsedAlbum.id {
            lastUsedAlbum = await DataActor.shared.album(for: id)
        } else {
            lastUsedAlbum = nil
        }
    }
}
