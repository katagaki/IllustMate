//
//  PhotosFolderView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Photos
import SwiftUI

struct PhotosFolderView: View {

    let folder: PHCollectionList
    var selectedAlbum: Album?
    var onDismiss: () -> Void

    @State private var items: [PHCollectionItem] = []
    @State private var hasFetched: Bool = false

    var body: some View {
        List {
            if items.isEmpty && hasFetched {
                ContentUnavailableView("Import.Folder.Empty", systemImage: "folder")
            } else {
                ForEach(items) { item in
                    switch item {
                    case .album(let collection):
                        albumRow(for: collection)
                    case .folder(let childFolder):
                        folderRow(for: childFolder)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PHAssetCollectionWrapper.self) { wrapper in
            PhotosAssetGridView(
                collection: wrapper.collection,
                selectedAlbum: selectedAlbum,
                onDismiss: onDismiss
            )
        }
        .navigationDestination(for: PHCollectionListWrapper.self) { wrapper in
            PhotosFolderView(
                folder: wrapper.collectionList,
                selectedAlbum: selectedAlbum,
                onDismiss: onDismiss
            )
        }
        .onAppear {
            if !hasFetched {
                fetchContents()
            }
        }
    }

    @ViewBuilder
    private func albumRow(for collection: PHAssetCollection) -> some View {
        NavigationLink(value: PHAssetCollectionWrapper(collection: collection)) {
            HStack(spacing: 12.0) {
                albumThumbnail(for: collection)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(collection.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                    Text("\(imageCount(in: collection))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .tint(.primary)
    }

    @ViewBuilder
    private func folderRow(for folder: PHCollectionList) -> some View {
        NavigationLink(value: PHCollectionListWrapper(collectionList: folder)) {
            HStack(spacing: 12.0) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                Text(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                Spacer()
            }
        }
        .tint(.primary)
    }

    @ViewBuilder
    private func albumThumbnail(for collection: PHAssetCollection) -> some View {
        if let firstAsset = firstAsset(in: collection) {
            PhotoThumbnailView(asset: firstAsset, size: CGSize(width: 56, height: 56))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func fetchContents() {
        let result = PHCollection.fetchCollections(in: folder, options: nil)
        var collected: [PHCollectionItem] = []

        result.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                collected.append(.album(album))
            } else if let subfolder = collection as? PHCollectionList {
                collected.append(.folder(subfolder))
            }
        }

        items = collected.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        hasFetched = true
    }

    private func imageCount(in collection: PHAssetCollection) -> Int {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: collection, options: fetchOptions).count
    }

    private func firstAsset(in collection: PHAssetCollection) -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(in: collection, options: fetchOptions).firstObject
    }
}
