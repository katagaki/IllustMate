//
//  PhotosFolderImportPickerView.swift
//  PicMate
//
//  Created on 2026/03/19.
//

import Photos
import SwiftUI

struct PhotosFolderImportPickerView: View {

    var folder: PHCollectionList?
    var selectedAlbum: Album?
    var onDismiss: () -> Void

    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var items: [PHCollectionItem] = []
    @State private var hasFetched: Bool = false

    @State private var isImporting: Bool = false
    @State private var isImportCompleted: Bool = false
    @State private var importCurrentCount: Int = 0
    @State private var importTotalCount: Int = 0
    @State private var importCompletedCount: Int = 0

    var body: some View {
        Group {
            if isImportCompleted {
                VStack {
                    StatusView(type: .success, title: .importCompleted(count: importCompletedCount))
                    Button {
                        onDismiss()
                    } label: {
                        Text("Shared.OK")
                            .bold()
                            .padding(4.0)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .padding(20.0)
                }
            } else if isImporting {
                StatusView(type: .inProgress, title: .importImporting,
                           currentCount: importCurrentCount, totalCount: importTotalCount)
            } else if folder != nil {
                folderListView
            } else {
                switch authorizationStatus {
                case .authorized, .limited:
                    folderListView
                case .denied, .restricted:
                    deniedView
                default:
                    ProgressView()
                        .onAppear {
                            requestAuthorization()
                        }
                }
            }
        }
        .navigationTitle(
            folder == nil
            ? String(localized: "Import.Albums", table: "Import")
            : (folder?.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import"))
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isImporting || isImportCompleted)
        .navigationDestination(for: PHCollectionListWrapper.self) { wrapper in
            PhotosFolderImportPickerView(
                folder: wrapper.collectionList,
                selectedAlbum: selectedAlbum,
                onDismiss: onDismiss
            )
        }
    }

    // MARK: - Folder List

    private var folderListView: some View {
        List {
            if items.isEmpty && hasFetched {
                ContentUnavailableView(
                    String(localized: "Import.Folder.Empty", table: "Import"),
                    systemImage: "folder"
                )
            } else {
                ForEach(items) { item in
                    switch item {
                    case .album:
                        EmptyView()
                    case .folder(let folder):
                        folderRow(for: folder)
                    }
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            if let folder {
                VStack(alignment: .center, spacing: 16.0) {
                    Button {
                        startFolderImport(folder)
                    } label: {
                        Text("Import.ImportFolder", tableName: "Import")
                            .bold()
                            .padding(4.0)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.accent)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                }
                .frame(maxWidth: .infinity)
                .padding(20.0)
            }
        }
        .onAppear {
            if !hasFetched {
                fetchFolders()
            }
        }
    }

    @ViewBuilder
    private func folderRow(for folder: PHCollectionList) -> some View {
        NavigationLink(value: PHCollectionListWrapper(collectionList: folder)) {
            HStack(spacing: 12.0) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                    }
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import"))
                    Text("Import.FolderContents.\(albumCount(in: folder)).\(totalImageCount(in: folder))",
                         tableName: "Import")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .tint(.primary)
    }

    // MARK: - Denied View

    private var deniedView: some View {
        VStack(spacing: 16.0) {
            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 64.0, height: 64.0)
                .foregroundStyle(.secondary)
            Text("Import.PhotosAccessDenied", tableName: "Import")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(String(localized: "Import.OpenSettings", table: "Import")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.glassProminent)
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

    private func fetchFolders() {
        var collected: [PHCollectionItem] = []

        if let folder {
            let result = PHCollection.fetchCollections(in: folder, options: nil)
            result.enumerateObjects { collection, _, _ in
                if let subfolder = collection as? PHCollectionList {
                    collected.append(.folder(subfolder))
                }
            }
        } else {
            let topLevelResult = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            topLevelResult.enumerateObjects { collection, _, _ in
                if let subfolder = collection as? PHCollectionList {
                    collected.append(.folder(subfolder))
                }
            }
        }

        items = collected.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        hasFetched = true
    }

    private func albumCount(in folder: PHCollectionList) -> Int {
        var count = 0
        let result = PHCollection.fetchCollections(in: folder, options: nil)
        result.enumerateObjects { collection, _, _ in
            if collection is PHAssetCollection {
                count += 1
            }
        }
        return count
    }

    private func totalImageCount(in folder: PHCollectionList) -> Int {
        countImagesRecursively(in: folder)
    }

    private func countImagesRecursively(in folder: PHCollectionList) -> Int {
        var count = 0
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        let result = PHCollection.fetchCollections(in: folder, options: nil)
        result.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                count += PHAsset.fetchAssets(in: album, options: fetchOptions).count
            } else if let subfolder = collection as? PHCollectionList {
                count += countImagesRecursively(in: subfolder)
            }
        }
        return count
    }

    // MARK: - Folder Import

    private func startFolderImport(_ folder: PHCollectionList) {
        isImporting = true
        importTotalCount = countImagesRecursively(in: folder)
        importCurrentCount = 0

        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            let folderName = folder.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import")
            let rootAlbum = await DataActor.shared.createAlbum(
                folderName, parentAlbumID: selectedAlbum?.id
            )

            await importFolderRecursively(folder, parentAlbumID: rootAlbum.id)

            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = importCurrentCount
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }

    private func importFolderRecursively(_ folder: PHCollectionList, parentAlbumID: String) async {
        let result = PHCollection.fetchCollections(in: folder, options: nil)
        var albums: [PHAssetCollection] = []
        var subfolders: [PHCollectionList] = []

        result.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                albums.append(album)
            } else if let subfolder = collection as? PHCollectionList {
                subfolders.append(subfolder)
            }
        }

        // Import albums as child albums
        for album in albums {
            let albumName = album.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import")
            let childAlbum = await DataActor.shared.createAlbum(albumName, parentAlbumID: parentAlbumID)
            await importPhotosFromAlbum(album, intoAlbumID: childAlbum.id)
        }

        // Recurse into subfolders
        for subfolder in subfolders {
            let subfolderName = subfolder.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import")
            let childAlbum = await DataActor.shared.createAlbum(subfolderName, parentAlbumID: parentAlbumID)
            await importFolderRecursively(subfolder, parentAlbumID: childAlbum.id)
        }
    }

    private func importPhotosFromAlbum(_ collection: PHAssetCollection, intoAlbumID albumID: String) async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assetResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true

        var assets: [PHAsset] = []
        assetResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        for asset in assets {
            let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                imageManager.requestImageDataAndOrientation(
                    for: asset, options: requestOptions
                ) { data, _, _, _ in
                    continuation.resume(returning: data)
                }
            }

            if let data {
                let resources = PHAssetResource.assetResources(for: asset)
                let filename = resources.first?.originalFilename ?? Pic.newFilename()
                await DataActor.shared.createPic(
                    filename, data: data,
                    inAlbumWithID: albumID,
                    dateAdded: asset.creationDate
                )
            }

            await MainActor.run {
                importCurrentCount += 1
            }
        }
    }
}
