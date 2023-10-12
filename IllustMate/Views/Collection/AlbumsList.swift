//
//  AlbumsList.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct AlbumsList: View {

    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    @Binding var albums: [Album]
    var onRename: (Album) -> Void
    var onDelete: (Album) -> Void
    var onDrop: (Drop, Album) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0.0) {
            ForEach(albums, id: \.id) { album in
                NavigationLink(value: ViewPath.album(album: album)) {
                    AlbumListRow(namespace: namespace, album: album)
                        .draggable(AlbumTransferable(id: album.id))
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
                if album != albums.last {
                    Divider()
                        .padding([.leading], 84.0)
                }
            }
        }
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
