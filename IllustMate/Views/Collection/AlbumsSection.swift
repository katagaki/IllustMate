//
//  AlbumsSection.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct AlbumsSection<Content: View>: View {

    @Environment(\.colorScheme) var colorScheme

    @Namespace var albumTransitionNamespace

    @Binding var albums: [Album]
    @Binding var style: ViewStyle
    var enablesContextMenu: Bool = true
    var onRename: ((Album) -> Void)?
    var onDelete: ((Album) -> Void)?
    var onDrop: ((Drop, Album) -> Void)?
    @ViewBuilder var moveMenu: (Album) -> Content

    let phoneColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 20.0)]
#if targetEnvironment(macCatalyst)
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 20.0)]
#else
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 160.0), spacing: 20.0)]
#endif

    var body: some View {
        Group {
            switch style {
            case .grid:
                LazyVGrid(columns: UIDevice.current.userInterfaceIdiom == .phone ?
                          phoneColumnConfiguration : padOrMacColumnConfiguration,
                          spacing: 20.0) {
                    ForEach(albums) { album in
                        NavigationLink(value: ViewPath.album(album: album)) {
                            if enablesContextMenu {
                                AlbumGridLabel(namespace: albumTransitionNamespace,
                                               album: album)
                                .draggable(AlbumTransferable(id: album.id))
                                .dropDestination(for: Drop.self) { items, _ in
                                    for item in items {
                                        if let onDrop {
                                            onDrop(item, album)
                                        }
                                    }
                                    return true
                                }
                            } else {
                                AlbumGridLabel(namespace: albumTransitionNamespace,
                                               album: album)
                            }
                        }
                        .id("\(album.id)-\(album.albums().count)-\(album.illustrations().count)")
                        .buttonStyle(.plain)
                        .contextMenu {
                            if enablesContextMenu {
                                moveMenu(album)
                                Divider()
                                Button("Shared.ResetCover", systemImage: "photo") {
                                    withAnimation(.snappy.speed(2)) {
                                        album.coverPhoto = nil
                                    }
                                }
                                Divider()
                                Button("Shared.Rename", systemImage: "pencil") {
                                    if let onRename {
                                        onRename(album)
                                    }
                                }
                                Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                    if let onDelete {
                                        onDelete(album)
                                    }
                                }
                            }
                        }
#if targetEnvironment(macCatalyst)
                        .buttonStyle(.borderless)
#else
                        .buttonStyle(.plain)
#endif
                    }
                }
                          .padding(20.0)
            case .list:
                LazyVStack(alignment: .leading, spacing: 0.0) {
                    ForEach(albums, id: \.id) { album in
                        NavigationLink(value: ViewPath.album(album: album)) {
                            AlbumListRow(namespace: albumTransitionNamespace, album: album)
                                .draggable(AlbumTransferable(id: album.id))
                                .dropDestination(for: Drop.self) { items, _ in
                                    for item in items {
                                        if let onDrop {
                                            onDrop(item, album)
                                        }
                                    }
                                    return true
                                }
                        }
                        .id("\(album.id)-\(album.albums().count)-\(album.illustrations().count)")
                        .buttonStyle(.plain)
                        .contextMenu {
                            moveMenu(album)
                            Divider()
                            Button("Shared.ResetCover", systemImage: "photo") {
                                withAnimation(.snappy.speed(2)) {
                                    album.coverPhoto = nil
                                }
                            }
                            Divider()
                            Button("Shared.Rename", systemImage: "pencil") {
                                if let onRename {
                                    onRename(album)
                                }
                            }
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                if let onDelete {
                                    onDelete(album)
                                }
                            }
                        }
#if targetEnvironment(macCatalyst)
                        .buttonStyle(.borderless)
#else
                        .buttonStyle(.plain)
#endif
                        if album != albums.last {
                            Divider()
                                .padding([.leading], 84.0)
                        }
                    }
                }
            }
        }
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
