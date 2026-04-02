//
//  AlbumView+Import.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/15.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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

    func importSelectedVideos(_ items: [PhotosPickerItem]) {
        isImportingPhotos = true
        importTotalCount = items.count
        importCurrentCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for item in items {
                var creationDate: Date?
                var filename: String?
                var videoDuration: TimeInterval = 0

                if let identifier = item.itemIdentifier {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                    if let asset = result.firstObject {
                        creationDate = asset.creationDate
                        let resources = PHAssetResource.assetResources(for: asset)
                        filename = resources.first?.originalFilename
                        videoDuration = asset.duration
                    }
                }

                await importVideoFromPicker(
                    item,
                    filename: filename ?? Pic.newVideoFilename(),
                    duration: videoDuration,
                    creationDate: creationDate
                )
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
                selectedVideoItems = []
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }

    private func importVideoFromPicker(
        _ item: PhotosPickerItem,
        filename: String,
        duration: TimeInterval,
        creationDate: Date?
    ) async {
        guard let identifier = item.itemIdentifier else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return }

        let videoOptions = PHVideoRequestOptions()
        videoOptions.isNetworkAccessAllowed = true
        videoOptions.deliveryMode = .highQualityFormat

        let exportSession: AVAssetExportSession? = await withCheckedContinuation {
            (continuation: CheckedContinuation<AVAssetExportSession?, Never>) in
            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: videoOptions,
                exportPreset: AVAssetExportPresetPassthrough
            ) { session, _ in
                nonisolated(unsafe) let result = session
                continuation.resume(returning: result)
            }
        }

        guard let exportSession else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov

        await exportSession.export()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard exportSession.status == .completed,
              let videoData = try? Data(contentsOf: tempURL) else { return }

        let fileExtension = (filename as NSString).pathExtension.isEmpty
            ? "mov" : (filename as NSString).pathExtension.lowercased()

        await DataActor.shared.createVideo(
            filename,
            data: videoData,
            duration: duration,
            fileExtension: fileExtension,
            inAlbumWithID: currentAlbum?.id,
            dateAdded: creationDate
        )
    }

    func importLoadedFiles(_ files: [(filename: String, data: Data)]) {
        isImportingPhotos = true
        importTotalCount = files.count
        importCurrentCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for file in files {
                let uti = UTType(filenameExtension: (file.filename as NSString).pathExtension)
                if uti?.conforms(to: .movie) == true || uti?.conforms(to: .video) == true {
                    let ext = (file.filename as NSString).pathExtension.lowercased()
                    await DataActor.shared.createVideo(
                        file.filename, data: file.data, duration: 0,
                        fileExtension: ext.isEmpty ? "mov" : ext,
                        inAlbumWithID: currentAlbum?.id
                    )
                } else {
                    await DataActor.shared.createPic(file.filename, data: file.data,
                                                     inAlbumWithID: currentAlbum?.id)
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
            var loadedImageFiles: [(filename: String, data: Data)] = []
            var loadedVideoFiles: [(filename: String, data: Data, duration: TimeInterval)] = []
            for fileURL in urls {
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing { fileURL.stopAccessingSecurityScopedResource() }
                }
                guard let data = try? Data(contentsOf: fileURL) else { continue }
                let uti = UTType(filenameExtension: fileURL.pathExtension)
                if uti?.conforms(to: .movie) == true || uti?.conforms(to: .video) == true {
                    let asset = AVURLAsset(url: fileURL)
                    let duration = (try? await asset.load(.duration))?.seconds ?? 0
                    loadedVideoFiles.append((filename: fileURL.lastPathComponent, data: data, duration: duration))
                } else if UIImage(data: data) != nil {
                    loadedImageFiles.append((filename: fileURL.lastPathComponent, data: data))
                }
            }
            for file in loadedImageFiles {
                await DataActor.shared.createPic(file.filename, data: file.data,
                                                 inAlbumWithID: currentAlbum?.id)
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            for file in loadedVideoFiles {
                let ext = (file.filename as NSString).pathExtension.lowercased()
                await DataActor.shared.createVideo(
                    file.filename, data: file.data, duration: file.duration,
                    fileExtension: ext.isEmpty ? "mov" : ext,
                    inAlbumWithID: currentAlbum?.id
                )
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                if let currentAlbum {
                    AlbumCoverCache.shared.removeImages(forAlbumID: currentAlbum.id)
                }
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = loadedImageFiles.count + loadedVideoFiles.count
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
