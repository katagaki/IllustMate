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

    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int
    @AppStorage(wrappedValue: false, "HideSectionHeaders",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var hideSectionHeaders: Bool

    var body: some View {
        Group {
            switch style {
            case .grid:
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10.0), count: columnCount),
                          spacing: 12.0) {
                    ForEach(albums) { album in
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
                .padding(.horizontal, 14.0)
                .padding(.top, hideSectionHeaders ? 0.0 : 10.0)
                .animation(.smooth.speed(2.0), value: columnCount)
            case .list:
                LazyVStack(alignment: .leading, spacing: 0.0) {
                    ForEach(albums) { album in
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
            case .carousel:
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 20.0) {
                        ForEach(albums) { album in
                            NavigationLink(value: ViewPath.album(album: album)) {
                                AlbumGridLabel(namespace: albumTransitionNamespace, album: album, length: 80.0)
                                    .draggable(AlbumTransferable(id: album.id))
                                    .albumDropDestination(onDrop: onDrop, album: album)
                            }
                            .id("\(album.identifiableString())")
                            .contextMenu {
                                contextMenu(album)
                            }
                            .buttonStyleAdaptive()
                        }
                    }
                    .padding(20.0)
                }
                .scrollIndicators(.hidden)
                .frame(height: 120.0)
            }
        }
    }

    @ViewBuilder
    func contextMenu(_ album: Album) -> some View {
        if enablesContextMenu {
            moveMenu(album)
            if album.hasCoverPhoto {
                Divider()
                Button("Shared.ResetCover", systemImage: "photo") {
                    Task {
                        await DataActor.shared.updateAlbumCover(forAlbumWithID: album.id, coverData: nil)
                        AlbumCoverCache.shared.removeImages(forAlbumID: album.id)
                    }
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
