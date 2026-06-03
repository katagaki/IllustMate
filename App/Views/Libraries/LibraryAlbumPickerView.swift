import SwiftUI

struct LibraryAlbumPickerView: View {

    let libraryID: String
    let parentAlbum: Album?
    let onOpen: (Album) -> Void
    let onMoveHere: () -> Void

    @State private var albums: [Album] = []
    @State private var isLoaded: Bool = false

    var body: some View {
        List {
            if isLoaded {
                if albums.isEmpty {
                    Text("Albums.NoMoreAlbums", tableName: "Albums")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(albums) { album in
                        Button {
                            onOpen(album)
                        } label: {
                            row(for: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onMoveHere()
            } label: {
                Text("Move.MoveHere", tableName: "Libraries")
                    .bold()
                    .padding(4.0)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .padding(20.0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    func row(for album: Album) -> some View {
        HStack(spacing: 12.0) {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.secondary)
            Text(album.name)
            Spacer()
            Text(verbatim: "\(album.albumCount() + album.picCount())")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    func load() async {
        let loaded = (try? await DataActor.instance(for: libraryID)
            .albumsWithCounts(in: parentAlbum, sortedBy: .nameAscending)) ?? []
        await MainActor.run {
            albums = loaded
            isLoaded = true
        }
    }
}
