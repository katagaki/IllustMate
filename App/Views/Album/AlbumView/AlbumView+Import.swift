//
//  AlbumView+Import.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/15.
//

import Photos
import PhotosUI
import SwiftUI

extension AlbumView {

    func importSelectedPhotos(_ items: [PhotosPickerItem]) {
        isImportingPhotos = true
        importTotalCount = items.count
        importCurrentCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    var creationDate: Date?
                    var filename: String?
                    if let identifier = item.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate
                            let resources = PHAssetResource.assetResources(for: asset)
                            filename = resources.first?.originalFilename
                        }
                    }
                    await DataActor.shared.createPic(filename ?? Pic.newFilename(), data: data,
                                                     inAlbumWithID: currentAlbum?.id,
                                                     dateAdded: creationDate)
                }
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                if let currentAlbum {
                    AlbumCoverCache.shared.removeImages(forAlbumID: currentAlbum.id)
                }
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = items.count
                selectedPhotoItems = []
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }

    func importLoadedFiles(_ files: [(filename: String, data: Data)]) {
        isImportingPhotos = true
        importTotalCount = files.count
        importCurrentCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for file in files {
                await DataActor.shared.createPic(file.filename, data: file.data,
                                                 inAlbumWithID: currentAlbum?.id)
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                if let currentAlbum {
                    AlbumCoverCache.shared.removeImages(forAlbumID: currentAlbum.id)
                }
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = files.count
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }

    func importFiles(_ urls: [URL]) {
        isImportingPhotos = true
        importTotalCount = urls.count
        importCurrentCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            // Read file data synchronously while security-scoped access is valid,
            // then perform async database work separately
            var loadedFiles: [(filename: String, data: Data)] = []
            for fileURL in urls {
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                if let data = try? Data(contentsOf: fileURL),
                   UIImage(data: data) != nil {
                    loadedFiles.append((filename: fileURL.lastPathComponent, data: data))
                }
                if didStartAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            for file in loadedFiles {
                await DataActor.shared.createPic(file.filename, data: file.data,
                                                 inAlbumWithID: currentAlbum?.id)
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                if let currentAlbum {
                    AlbumCoverCache.shared.removeImages(forAlbumID: currentAlbum.id)
                }
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = loadedFiles.count
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
