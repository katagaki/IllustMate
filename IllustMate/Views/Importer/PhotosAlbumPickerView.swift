//
//  PhotosAlbumPickerView.swift
//  IllustMate
//
//  Created on 2026/02/22.
//

import Photos
import SwiftUI

struct PhotosAlbumPickerView: View {

    var selectedAlbum: Album?
    var onDismiss: () -> Void

    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var items: [PHCollectionItem] = []
    @State private var hasFetched: Bool = false

    var body: some View {
        Group {
            switch authorizationStatus {
            case .authorized, .limited:
                albumListView
            case .denied, .restricted:
                deniedView
            default:
                ProgressView()
                    .onAppear {
                        requestAuthorization()
                    }
            }
        }
        .navigationTitle("Import.Albums")
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
    }

    // MARK: - Album List

    private var albumListView: some View {
        List {
            ForEach(items) { item in
                switch item {
                case .album(let collection):
                    albumRow(for: collection)
                case .folder(let folder):
                    folderRow(for: folder)
                }
            }
        }
        .listStyle(.insetGrouped)
        .onAppear {
            if !hasFetched {
                fetchAlbums()
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

    // MARK: - Denied View

    private var deniedView: some View {
        VStack(spacing: 16.0) {
            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 64.0, height: 64.0)
                .foregroundStyle(.secondary)
            Text("Import.PhotosAccessDenied")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Import.OpenSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(40.0)
    }

    // MARK: - Helpers

    private func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authorizationStatus = status
            }
        }
    }

    private func fetchAlbums() {
        let topLevelResult = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        var collected: [PHCollectionItem] = []

        topLevelResult.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                collected.append(.album(album))
            } else if let folder = collection as? PHCollectionList {
                collected.append(.folder(folder))
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
