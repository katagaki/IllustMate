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

    var albums: [Album]
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
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 100.0), spacing: 20.0)]
#endif

    var body: some View {
        Group {
            switch style {
            case .grid:
                LazyVGrid(columns: UIDevice.current.userInterfaceIdiom == .phone ?
                          phoneColumnConfiguration : padOrMacColumnConfiguration,
                          spacing: 20.0) {
                    ForEach(albums, id: \.persistentModelID) { album in
                        NavigationLink(value: ViewPath.album(album: album)) {
                            if enablesContextMenu {
                                AlbumGridLabel(namespace: albumTransitionNamespace, album: album)
                                .draggable(AlbumTransferable(id: album.id))
                                .albumDropDestination(onDrop: onDrop, album: album)
                            } else {
                                AlbumGridLabel(namespace: albumTransitionNamespace,
                                               album: album)
                            }
                        }
                        .id("\(album.identifiableString())")
                        .contextMenu {
                            contextMenu(album)
                        }
                        .buttonStyleAdaptive()
                    }
                }
                          .padding(20.0)
            case .list:
                LazyVStack(alignment: .leading, spacing: 0.0) {
                    ForEach(albums, id: \.persistentModelID) { album in
                        NavigationLink(value: ViewPath.album(album: album)) {
                            AlbumListRow(namespace: albumTransitionNamespace, album: album)
                                .draggable(AlbumTransferable(id: album.id))
                                .albumDropDestination(onDrop: onDrop, album: album)
                        }
                        .id("\(album.identifiableString())")
                        .contextMenu {
                            contextMenu(album)
                        }
                        .buttonStyleAdaptive()
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

    @ViewBuilder
    func contextMenu(_ album: Album) -> some View {
        if enablesContextMenu {
            moveMenu(album)
            Divider()
            Button("Shared.ResetCover", systemImage: "photo") {
                doWithAnimationAsynchronously {
                    album.coverPhoto = nil
                }
            }
            if onRename != nil || onDelete != nil {
                Divider()
            }
            if let onRename {
                Button("Shared.Rename", systemImage: "pencil") {
                    onRename(album)
                }
            }
            if let onDelete {
                Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                    onDelete(album)
                }
            }
        }
    }
}
