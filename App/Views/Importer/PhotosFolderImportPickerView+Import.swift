//
//  PhotosFolderImportPickerView+Import.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import Photos
import SwiftUI

extension PhotosFolderImportPickerView {

    func startFolderImport(_ folder: PHCollectionList) {
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
                if let selectedAlbum {
                    AlbumCoverCache.shared.removeImages(forAlbumID: selectedAlbum.id)
                }
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = importCurrentCount
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }

    func importFolderRecursively(_ folder: PHCollectionList, parentAlbumID: String) async {
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

    func importPhotosFromAlbum(_ collection: PHAssetCollection, intoAlbumID albumID: String) async {
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
