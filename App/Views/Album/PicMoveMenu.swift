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
            if !rootAlbums.isEmpty {
                Section {
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

    func loadAlbums() async {
        rootAlbums = (try? await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)) ?? []
    }
}
