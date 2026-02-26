//
//  PhotosItemsGrid.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosItemsGrid: View {

    var items: [PHCollectionItem]

    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 20.0), count: columnCount),
            spacing: 20.0
        ) {
            ForEach(items) { item in
                switch item {
                case .album(let collection):
                    NavigationLink(value: ViewPath.photosAlbum(album: PHAssetCollectionWrapper(collection: collection))) {
                        PhotosAlbumGridLabel(collection: collection)
                    }
                    .buttonStyleAdaptive()
                case .folder(let folder):
                    NavigationLink(value: ViewPath.photosFolder(folder: PHCollectionListWrapper(collectionList: folder))) {
                        PhotosFolderGridLabel(folder: folder)
                    }
                    .buttonStyleAdaptive()
                }
            }
        }
        .padding(20.0)
    }
}

// MARK: - Album Grid Label

struct PhotosAlbumGridLabel: View {

    let collection: PHAssetCollection

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                    .fill(Color(.systemGray5))
                    .aspectRatio(1.0, contentMode: .fit)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .continuous))
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
            Text(collection.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .task {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        guard let asset = PHAsset.fetchAssets(in: collection, options: fetchOptions).firstObject else { return }

        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: 200, height: 200)

        manager.requestImage(for: asset, targetSize: targetSize,
                             contentMode: .aspectFill, options: options) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.thumbnail = result
                }
            }
        }
    }
}

// MARK: - Folder Grid Label

struct PhotosFolderGridLabel: View {

    let folder: PHCollectionList

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                    .fill(Color(.systemGray5))
                    .aspectRatio(1.0, contentMode: .fit)
                Image(systemName: "folder.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .continuous))
            Text(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}
