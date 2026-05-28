//
//  DataActor+ImageStorage.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {

    static let imagesDirectoryName = "Images"

    nonisolated func imagesDirectoryURL() -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
    }

    func ensureImagesDirectoryExists() {
        let url = imagesDirectoryURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Image bytes are stored verbatim; the extension is irrelevant since the
    /// data is always read back raw and decoded via `UIImage(data:)`.
    func saveImageFile(_ data: Data, id: String) -> String? {
        ensureImagesDirectoryExists()
        let relativePath = "\(Self.imagesDirectoryName)/\(id)"
        let fileURL = imagesDirectoryURL().appendingPathComponent(id)
        do {
            try data.write(to: fileURL)
            return relativePath
        } catch {
            debugPrint("Failed to save image file: \(error)")
            return nil
        }
    }

    nonisolated func imageFileURL(forRelativePath path: String) -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    func deleteImageFile(atRelativePath path: String) {
        let fileURL = imageFileURL(forRelativePath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated func isImagePath(_ path: String) -> Bool {
        path.hasPrefix("\(Self.imagesDirectoryName)/")
    }

    /// Writes an original fetched from iCloud Drive into the local Images cache
    /// and points the pic at it. Does not mark the pic dirty (sync-driven).
    func importDownloadedOriginal(picID: String, data: Data) {
        guard let relativePath = saveImageFile(data, id: picID) else { return }
        _ = try? database.run(picsTable.filter(picId == picID)
            .update(picFilePath <- relativePath, picData <- nil, syncOriginalSynced <- true))
    }
}
