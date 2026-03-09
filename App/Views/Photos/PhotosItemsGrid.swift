//
//  PhotosAlbumsSection.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosAlbumsSection: View {

    var items: [PHCollectionItem]
    @Binding var style: ViewStyle
    var enablesContextMenu: Bool = true
    var onRename: ((PHAssetCollection) -> Void)?
    var onDelete: ((PHAssetCollection) -> Void)?
    var onMoveToFolder: ((PHAssetCollection) -> Void)?
    var onDeleteFolder: ((PHCollectionList) -> Void)?

    @Namespace var albumTransitionNamespace

    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int

    var body: some View {
        Group {
            switch style {
            case .grid:
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 20.0), count: columnCount),
                    spacing: 20.0
                ) {
                    ForEach(items) { item in
                        itemLink(for: item) {
                            itemGridLabel(for: item)
                        }
                        .contextMenu { contextMenu(for: item) }
                        .buttonStyleAdaptive()
                    }
                }
                .padding(20.0)
                .animation(.smooth, value: columnCount)
            case .list:
                LazyVStack(alignment: .leading, spacing: 0.0) {
                    ForEach(items) { item in
                        itemLink(for: item) {
                            itemListRow(for: item)
                        }
                        .contextMenu { contextMenu(for: item) }
                        .buttonStyleAdaptive()
                        if item.id != items.last?.id {
                            Divider()
                                .padding([.leading], 84.0)
                        }
                    }
                }
            case .carousel:
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 20.0) {
                        ForEach(items) { item in
                            itemLink(for: item) {
                                itemGridLabel(for: item, length: 80.0)
                            }
                            .contextMenu { contextMenu(for: item) }
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

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for item: PHCollectionItem) -> some View {
        if enablesContextMenu {
            switch item {
            case .album(let collection):
                if let onMoveToFolder {
                    Button("Photos.MoveToFolder", systemImage: "folder") {
                        onMoveToFolder(collection)
                    }
                }
                if let onRename {
                    Divider()
                    Button("Shared.Rename", systemImage: "pencil") {
                        onRename(collection)
                    }
                }
                if let onDelete {
                    Divider()
                    Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                        onDelete(collection)
                    }
                }
            case .folder(let folder):
                if let onDeleteFolder {
                    Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                        onDeleteFolder(folder)
                    }
                }
            }
        }
    }

    // MARK: - Navigation Links

    @ViewBuilder
    private func itemLink<Label: View>(
        for item: PHCollectionItem,
        @ViewBuilder label: () -> Label
    ) -> some View {
        switch item {
        case .album(let collection):
            NavigationLink(value: ViewPath.photosAlbum(
                album: PHAssetCollectionWrapper(collection: collection))) {
                label()
            }
        case .folder(let folder):
            NavigationLink(value: ViewPath.photosFolder(
                folder: PHCollectionListWrapper(collectionList: folder))) {
                label()
            }
        }
    }

    // MARK: - Grid Labels

    @ViewBuilder
    private func itemGridLabel(for item: PHCollectionItem, length: CGFloat? = nil) -> some View {
        switch item {
        case .album(let collection):
            PhotosAlbumGridLabel(namespace: albumTransitionNamespace,
                                 collection: collection, length: length)
        case .folder(let folder):
            PhotosFolderGridLabel(namespace: albumTransitionNamespace,
                                  folder: folder, length: length)
        }
    }

    // MARK: - List Rows

    @ViewBuilder
    private func itemListRow(for item: PHCollectionItem) -> some View {
        switch item {
        case .album(let collection):
            PhotosAlbumListRow(namespace: albumTransitionNamespace, collection: collection)
        case .folder(let folder):
            PhotosFolderListRow(namespace: albumTransitionNamespace, folder: folder)
        }
    }
}

// MARK: - Album Grid Label

struct PhotosAlbumGridLabel: View {

    var namespace: Namespace.ID
    var collection: PHAssetCollection
    var length: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover.AsyncPhotosAlbumCover(collection: collection, length: length)
                .matchedGeometryEffect(id: "\(collection.localIdentifier).Image", in: namespace)
            Text(collection.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                .matchedGeometryEffect(id: "\(collection.localIdentifier).Title", in: namespace)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .frame(width: length)
    }
}

// MARK: - Folder Grid Label

struct PhotosFolderGridLabel: View {

    var namespace: Namespace.ID
    var folder: PHCollectionList
    var length: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover.AsyncPhotosFolderCover(folder: folder, length: length)
                .matchedGeometryEffect(id: "\(folder.localIdentifier).Image", in: namespace)
            Text(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                .matchedGeometryEffect(id: "\(folder.localIdentifier).Title", in: namespace)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .frame(width: length)
    }
}

// MARK: - Album List Row

struct PhotosAlbumListRow: View {

    var namespace: Namespace.ID
    var collection: PHAssetCollection

    @State private var picCount: Int = 0

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            AlbumCover.AsyncPhotosAlbumCover(collection: collection, length: 48.0)
                .matchedGeometryEffect(id: "\(collection.localIdentifier).Image", in: namespace)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(collection.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                    .matchedGeometryEffect(id: "\(collection.localIdentifier).Title", in: namespace)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Shared.Album.\(picCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .resizable()
                .scaledToFit()
                .frame(width: 11.0, height: 11.0)
                .foregroundStyle(.primary.opacity(0.25))
                .fontWeight(.bold)
        }
        .contentShape(.rect)
        .padding([.leading, .trailing], 20.0)
        .padding([.top, .bottom], 8.0)
        .task(id: collection.localIdentifier) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            picCount = PHAsset.fetchAssets(in: collection, options: options).count
        }
    }
}

// MARK: - Folder List Row

struct PhotosFolderListRow: View {

    var namespace: Namespace.ID
    var folder: PHCollectionList

    @State private var childCount: Int = 0

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            AlbumCover.AsyncPhotosFolderCover(folder: folder, length: 48.0)
                .matchedGeometryEffect(id: "\(folder.localIdentifier).Image", in: namespace)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                    .matchedGeometryEffect(id: "\(folder.localIdentifier).Title", in: namespace)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Shared.Album.\(childCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .resizable()
                .scaledToFit()
                .frame(width: 11.0, height: 11.0)
                .foregroundStyle(.primary.opacity(0.25))
                .fontWeight(.bold)
        }
        .contentShape(.rect)
        .padding([.leading, .trailing], 20.0)
        .padding([.top, .bottom], 8.0)
        .task(id: folder.localIdentifier) {
            childCount = PHCollection.fetchCollections(in: folder, options: nil).count
        }
    }
}
