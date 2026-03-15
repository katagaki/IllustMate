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

    func importFiles(_ urls: [URL]) {
        isImportingPhotos = true
        importTotalCount = urls.count
        importCurrentCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for fileURL in urls {
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                if let data = try? Data(contentsOf: fileURL),
                   UIImage(data: data) != nil {
                    let filename = fileURL.lastPathComponent
                    await DataActor.shared.createPic(filename, data: data,
                                                     inAlbumWithID: currentAlbum?.id)
                }
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = urls.count
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
