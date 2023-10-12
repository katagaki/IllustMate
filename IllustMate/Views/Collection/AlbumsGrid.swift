//
//  AlbumsGrid.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftData
import SwiftUI

struct AlbumsGrid: View {

    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    @Binding var albums: [Album]
    var onRename: (Album) -> Void
    var onDelete: (Album) -> Void
    var onDrop: (Drop, Album) -> Void

    let phoneColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 20.0)]
#if targetEnvironment(macCatalyst)
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 20.0)]
#else
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 160.0), spacing: 20.0)]
#endif

    var body: some View {
        LazyVGrid(columns: UIDevice.current.userInterfaceIdiom == .phone ?
                  phoneColumnConfiguration : padOrMacColumnConfiguration,
                  spacing: 20.0) {
            ForEach(albums) { album in
                NavigationLink(value: ViewPath.album(album: album)) {
                    AlbumGridLabel(namespace: namespace,
                                   album: album)
                    .dropDestination(for: Drop.self) { items, _ in
                        for item in items {
                            onDrop(item, album)
                        }
                        return true
                    }
                }
                .id("\(album.id)-\(album.albums().count)-\(album.illustrations().count)")
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Shared.ResetCover", systemImage: "photo") {
                        withAnimation(.snappy.speed(2)) {
                            album.coverPhoto = nil
                        }
                    }
                    Divider()
                    Button("Shared.Rename", systemImage: "pencil") {
                        onRename(album)
                    }
                    Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                        onDelete(album)
                    }
                }
            }
        }
        .padding(20.0)
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
